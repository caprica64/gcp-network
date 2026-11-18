# Architecture

```mermaid
flowchart TB
    internet((Internet))
    iap[Identity-Aware Proxy<br/>35.235.240.0/20]

    subgraph devproj["GCP project: rm-lab-w1 (development, Shared VPC host)"]
        direction TB
        subgraph devvpc["VPC: main-vpc (global, custom mode, ULA IPv6)"]
            direction TB
            devroutes["<b>VPC routes</b> (no per-subnet route tables)<br/>10.0.1.0/24 → private-subnet<br/>10.0.2.0/24 → public-subnet<br/>IPv6 /64 of each subnet → local<br/>0.0.0.0/0 and ::/0 → default-internet-gateway"]
            subgraph devregion["Region: us-central1"]
                direction TB
                subgraph devpub["public-subnet<br/>IPv4 10.0.2.0/24<br/>IPv6 external /64"]
                    devpublicvm["public-vm<br/>external IPv4 + IPv6"]
                end
                subgraph devpriv["private-subnet<br/>IPv4 10.0.1.0/24<br/>IPv6 internal ULA /64"]
                    devprivatevm["private-vm<br/>internal IPv4 + IPv6"]
                end
                devnat["Cloud Router + Cloud NAT<br/>(IPv4 egress only)"]
            end
            devfw["Firewall: allow-internal, allow-internal-ipv6, allow-iap-ssh"]
        end
        devlog[("Cloud Logging<br/>VPC Flow Logs")]
    end

    subgraph prodproj["GCP project: rm-lab-prod (production, Shared VPC host)"]
        direction TB
        subgraph prodvpc["VPC: main-vpc (global, custom mode, ULA IPv6)"]
            direction TB
            prodroutes["<b>VPC routes</b> (no per-subnet route tables)<br/>10.1.1.0/24 → private-subnet<br/>10.1.2.0/24 → public-subnet<br/>IPv6 /64 of each subnet → local<br/>0.0.0.0/0 and ::/0 → default-internet-gateway"]
            subgraph prodregion["Region: us-central1"]
                direction TB
                subgraph prodpub["public-subnet<br/>IPv4 10.1.2.0/24<br/>IPv6 external /64"]
                    prodpublicvm["public-vm<br/>external IPv4 + IPv6"]
                end
                subgraph prodpriv["private-subnet<br/>IPv4 10.1.1.0/24<br/>IPv6 internal ULA /64"]
                    prodprivatevm["private-vm<br/>internal IPv4 + IPv6"]
                end
                prodnat["Cloud Router + Cloud NAT<br/>(IPv4 egress only)"]
            end
            prodfw["Firewall: allow-internal, allow-internal-ipv6, allow-iap-ssh"]
        end
        prodlog[("Cloud Logging<br/>VPC Flow Logs")]
    end

    svc["Service projects<br/>(attach to a host project as needed)"]

    devroutes -.->|"applies to"| devpub
    devroutes -.->|"applies to"| devpriv
    devpublicvm <-->|"subnet routes + allow-internal"| devprivatevm
    devpublicvm <-->|"default routes (external IPs)"| internet
    devprivatevm -->|"outbound IPv4"| devnat
    devnat --> internet
    iap -.->|"SSH"| devpublicvm
    iap -.->|"SSH"| devprivatevm
    devpub -.->|"flow logs"| devlog
    devpriv -.->|"flow logs"| devlog

    prodroutes -.->|"applies to"| prodpub
    prodroutes -.->|"applies to"| prodpriv
    prodpublicvm <-->|"subnet routes + allow-internal"| prodprivatevm
    prodpublicvm <-->|"default routes (external IPs)"| internet
    prodprivatevm -->|"outbound IPv4"| prodnat
    prodnat --> internet
    iap -.->|"SSH"| prodpublicvm
    iap -.->|"SSH"| prodprivatevm
    prodpub -.->|"flow logs"| prodlog
    prodpriv -.->|"flow logs"| prodlog

    svc -.->|"Shared VPC"| devvpc
    svc -.->|"Shared VPC"| prodvpc
```

## Notes

- Two GCP projects, each a Shared VPC host: development (rm-lab-w1, 10.0.0.0/16) and production (rm-lab-prod, 10.1.0.0/16). The ranges do not overlap.
- Both use the same module (modules/network), with settings in envs/dev and envs/prod.
- GCP VPCs are global. The /16 ranges are only the space the subnets are carved from.
- GCP has no route tables. Routes belong to the VPC and apply to every subnet.
- Each environment has a test VM in each subnet.
- Both projects send VPC Flow Logs to Cloud Logging.
- Inbound internet traffic to the public VMs is blocked until you add an ingress firewall rule.
- Service projects are not created by this Terraform.
