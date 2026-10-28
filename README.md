# Three-Tier AWS Architecture with Terraform

A three-tier web architecture on AWS, defined entirely in Terraform: a public web tier, a private application tier, and a private database tier, spread across two Availability Zones with security groups that chain tier to tier.

![Architecture diagram](docs/architecture.png)

## What it builds

| Layer | Resources |
|---|---|
| Network | 1 VPC (`10.0.0.0/16`), 6 subnets across `us-east-1a` and `us-east-1b`, internet gateway, NAT gateway, public and private route tables |
| Web tier | Internet-facing Application Load Balancer, Auto Scaling group (2 to 4 `t3.micro`) in public subnets, running nginx |
| App tier | Internal Application Load Balancer, Auto Scaling group (2 to 4 `t3.micro`) in private subnets, running nginx |
| Database tier | RDS PostgreSQL (`db.t3.micro`) in private DB subnets, encrypted, not publicly accessible, password managed by Secrets Manager |
| Access and IAM | EC2 instance profile with `AmazonSSMManagedInstanceCore`, so instances are managed through Session Manager (no SSH, no bastion host) |

About 38 resources in total.

## Traffic flow

```
User
  │  HTTP :80
  ▼
Internet Gateway
  ▼
Web ALB (public subnets, web-alb-sg)
  ▼
Web ASG instances (public subnets, web-ec2-sg)
  │  HTTP :80
  ▼
App ALB (internal, private app subnets, app-alb-sg)
  ▼
App ASG instances (private app subnets, app-ec2-sg)
  │  PostgreSQL :5432
  ▼
RDS (private DB subnets, db-sg)
```

Private instances reach the internet (package installs, SSM) outbound only, through the NAT gateway.

## Security design

Each security group allows inbound traffic only from the tier directly above it, referencing security groups rather than CIDR ranges.

| Security group | Allows inbound from | Port |
|---|---|---|
| `web_alb_sg` | Internet (`0.0.0.0/0`) | 80 |
| `web_ec2_sg` | `web_alb_sg` | 80 |
| `app_alb_sg` | `web_ec2_sg` | 80 |
| `app_ec2_sg` | `app_alb_sg` | 80 |
| `db_sg` | `app_ec2_sg` | 5432 |

Other controls:

- **IMDSv2 required** on all launch templates (`http_tokens = "required"`), which blocks the SSRF-to-credentials attack path that IMDSv1 allows.
- **No SSH and no bastion host.** Access is through AWS Systems Manager Session Manager using an IAM instance profile, so there are no inbound admin ports and no key pairs to manage.
- **RDS** has `storage_encrypted = true`, `publicly_accessible = false`, and `manage_master_user_password = true`, so the password lives in Secrets Manager and never appears in code or `.tfvars`.
- **Private subnets** do not assign public IPs, and the internal ALB has no public address.
- **ELB health checks** drive the Auto Scaling groups, so unhealthy instances are replaced automatically.

## Repository layout

```
.
├── provider.tf    # Terraform and AWS provider configuration
├── network.tf     # VPC, subnets, IGW, NAT, route tables, associations
├── iam.tf         # SSM role, policy attachment, instance profile
├── security.tf    # Security groups for ALBs, EC2 tiers, and database
├── alb.tf         # Web and app load balancers, target groups, listeners
├── compute.tf     # AMI lookup, launch templates, Auto Scaling groups
├── database.tf    # RDS subnet group and PostgreSQL instance
├── output.tf      # ALB DNS names
└── docs/
    └── architecture.png
```

## Deploy

**Requirements:** Terraform, AWS credentials for a sandbox account with permission to create the resources above, and the AWS provider `~> 6.0`.

```bash
terraform init
terraform fmt && terraform validate
terraform plan
terraform apply
```

Allow 10 to 15 minutes. RDS and the NAT gateway take the longest. After the apply, wait another few minutes for instances to boot and pass health checks.

Useful outputs:

```bash
terraform output web_alb_dns
terraform output app_alb_dns
terraform output db_endpoint
```

## Cost and cleanup

This stack bills hourly while it runs (NAT gateway, two ALBs, four EC2 instances, RDS, and public IPv4 addresses), roughly a few dollars per day. Destroy it when you finish testing:

```bash
terraform destroy
```

`skip_final_snapshot = true` and `deletion_protection = false` are set so that `destroy` works. Reverse both for anything real.

## Testing

Commands run from my laptop are marked **laptop**. Commands run on an EC2 instance through Session Manager are marked **web EC2** or **app EC2**.

### Web tier is reachable and load balanced (laptop)

```
$ curl http://$(terraform output -raw web_alb_dns)
Web tier from ip-10-0-7-8.ec2.internal

$ for i in {1..10}; do curl -s http://$(terraform output -raw web_alb_dns); done
Web tier from ip-10-0-23-238.ec2.internal
Web tier from ip-10-0-7-8.ec2.internal
Web tier from ip-10-0-7-8.ec2.internal
Web tier from ip-10-0-23-238.ec2.internal
Web tier from ip-10-0-23-238.ec2.internal
Web tier from ip-10-0-7-8.ec2.internal
Web tier from ip-10-0-7-8.ec2.internal
Web tier from ip-10-0-23-238.ec2.internal
Web tier from ip-10-0-7-8.ec2.internal
Web tier from ip-10-0-23-238.ec2.internal
```

Responses alternate between two instances in different subnets and AZs.

### Web tier can reach the internal app ALB (web EC2)

```
$ curl http://<app-alb-internal-dns>
App tier from ip-10-0-146-3.ec2.internal
```

### App tier is load balanced (web EC2)

```
$ for i in {1..10}; do curl -s http://<app-alb-internal-dns>; done
App tier from ip-10-0-139-164.ec2.internal
App tier from ip-10-0-146-3.ec2.internal
App tier from ip-10-0-146-3.ec2.internal
App tier from ip-10-0-139-164.ec2.internal
...
```

Responses alternate between two app instances.

### App ALB is not reachable from the internet (laptop)

```
$ curl --max-time 5 http://<app-alb-internal-dns>
curl: (28) Connection timed out after 5001 milliseconds
```

### Instance mapping

| Instance IP | Subnet | AZ | Tier |
|---|---|---|---|
| `10.0.7.8` | `10.0.0.0/20` (public) | us-east-1a | Web |
| `10.0.23.238` | `10.0.16.0/20` (public) | us-east-1b | Web |
| `10.0.139.164` | `10.0.128.0/20` (private) | us-east-1a | App |
| `10.0.146.3` | `10.0.144.0/20` (private) | us-east-1b | App |

### Summary

| Test | Run from | Expected | Result |
|---|---|---|---|
| Web ALB serves traffic | laptop | Response from web tier | Pass |
| Web ALB balances across 2 instances | laptop | Alternating hostnames | Pass |
| Web tier reaches app ALB | web EC2 | Response from app tier | Pass |
| App ALB balances across 2 instances | web EC2 | Alternating hostnames | Pass |
| App ALB blocked from internet | laptop | Timeout | Pass |
| Web instance public IP blocked on port 80 | laptop | Timeout | _TODO_ |
| App tier can connect to database | app EC2 | Port open / `psql` connects | _TODO_ |
| Web tier blocked from database | web EC2 | Port blocked | _TODO_ |
| Database blocked from internet | laptop | Port blocked | _TODO_ |

Port check used for the database tests:

```bash
timeout 5 bash -c '</dev/tcp/<db-address>/5432' && echo "OPEN" || echo "BLOCKED"
```

## Known limitations and next steps

This is a learning and portfolio build. Things I would change for production:

- **Single NAT gateway.** It is a single point of failure and incurs cross-AZ traffic. Production uses one per AZ.
- **HTTP only.** Adding HTTPS needs a domain, an ACM certificate, a 443 listener, and an HTTP-to-HTTPS redirect.
- **One IAM role shared by both tiers.** Least privilege calls for a separate role per tier, with scoped permissions (for example, only the app tier reading the database secret).
- **RDS is single-AZ.** Set `multi_az = true` for automatic failover.
- **DB subnets use the private route table.** They need no internet route, so an isolated route table would be stricter.
- **Software installed at boot with `user_data`.** Production would bake a golden AMI (Packer or EC2 Image Builder).
- **Web and app tiers serve static pages.** The tiers are connected at the network and security group level, but the web tier does not yet call the app tier from application code.
- **Local Terraform state.** A shared setup would use an S3 backend with versioning, encryption, and state locking.
- **Refactor into modules** (network, ASG tier, ALB) once a second environment is needed.
- Add `default_tags`, encrypted EBS volumes in the launch templates, and security scanning (tflint, checkov) in CI.

## Tech

Terraform, AWS (VPC, EC2, Auto Scaling, ELB, RDS, IAM, Systems Manager, Secrets Manager), Amazon Linux 2023, nginx, PostgreSQL.