# UFSCar Free Software Mirror

> **Where Free Software Meets Free Infrastructure**

A community-powered Linux distribution mirror with fully transparent operations - featuring open-source management, public metrics, and CI/CD deployment. Proudly hosted at the [Federal University of São Carlos](https://ufscar.br) in partnership with [PATOS](https://patos.dev) and [GELOS](https://gelos.club).

🌐 **Mirror URL**: https://mirror.ufscar.br

## 🤝 Community Partnership
This mirror is maintained through the joint effort of:
- [PATOS](https://patos.dev): Free Software Group at UFSCar  
- [GELOS](https://gelos.club): Free Software Group at USP São Carlos

Join our communities to contribute to free software infrastructure!

## 🔧 Technical Infrastructure
- **Operating System**: [NixOS](https://nixos.org) for reproducible, declarative infrastructure
- **Hardware**: Physical server hosted at UFSCar's datacenter  
  - Location: Secretaria Geral de Informática building, São Carlos
  - Connectivity: See https://bgp.tools/as/52888
- **Management**: Fully automated via GitHub CI/CD
- **Transparency**: All configuration and management code is public

## 📊 Live Monitoring & Metrics
We believe in operational transparency:

### Real-time Dashboard
[![Public Dashboard](https://img.shields.io/badge/Live_Metrics-Public_Dashboard-774aa4?logo=datadog&style=flat)](https://p.us5.datadoghq.com/sb/3b4452e8-11b2-11f0-95f9-1ea5f11b227d-7fd00bf61e9d5674c26afe4c9f89bdd1)  
Track real-time performance including:
- CPU/RAM usage & I/O wait
- Network traffic (packets/s, errors)
- Nginx connections & HTTP requests
- Disk usage/latency with future projections
- Storage read/write operations

### Alert System
[![Telegram Alerts](https://img.shields.io/badge/Instant_Alerts-Telegram_Channel-26A5E4?logo=telegram)](https://t.me/mirror_ufscar_br_alerts)  
Receive immediate notifications for system events

## 🛠️ Monitoring Infrastructure
- **Source Code**: [PATOS/mirror-monitoring](https://github.com/patos-ufscar/mirror-monitoring)
- **Deployment**: Automated CI/CD to Google CloudRun

## ✨ Contributing
We welcome community contributions!
- Submit pull requests for mirror configuration
- Improve monitoring in [PATOS/mirror-monitoring](https://github.com/patos-ufscar/mirror-monitoring)
- Join PATOS/GELOS meetings
- Suggest new metrics or visualizations

## 🌐 Why "Free Meets Free"?
- **Free Software**: We mirror only Free Software distributions
- **Free Infrastructure**: Entire stack is Free Software
- **Free Access**: Public metrics and management
- **Free Community**: Jointly maintained with PATOS & GELOS

[![UFSCar](https://img.shields.io/badge/Hosted%20by-UFSCar-00529B?style=flat&logo=university)](https://ufscar.br)
[![PATOS](https://img.shields.io/badge/Partner-PATOS-8CA1AF?style=flat)](https://patos.dev)
[![GELOS](https://img.shields.io/badge/Partner-GELOS-3D85C6?style=flat)](https://gelos.club)
