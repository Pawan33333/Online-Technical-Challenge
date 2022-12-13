provider "google" {
  credentials = file("marine-lacing-371009-373cfd724760.json")
  project = "marine-lacing-371009"
  region  = "asia-south1"
  zone    = "asia-south1-c"
}

resource "google_compute_network" "vpc_network1" {
  name = "web-tier"
  auto_create_subnetworks = "true"
}
resource "google_compute_network" "vpc_network2" {
  name = "app-tier"
  auto_create_subnetworks = "true"
}
resource "google_compute_network" "vpc_network3" {
  name = "db-tier"
  auto_create_subnetworks = "true"
}
 data "google_compute_image" "my_image" {
  family  = "debian-11"
  project = "debian-cloud"
}
resource "google_compute_instance_template" "default" {
  name        = "webserver-template"
  description = "This template is used to create app server instances."

  tags = ["foo", "bar"]

  labels = {
    environment = "dev"
  }

  instance_description = "description assigned to instances"
  machine_type         = "e2-medium"
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  // Create a new boot disk from an image
  disk {
    source_image      = "debian-cloud/debian-11"
    auto_delete       = true
    boot              = true
	}
	network_interface {
    network = "web-tier"
  }

  metadata = {
    foo = "bar"
  }
 
}
resource "google_compute_health_check" "autohealing" {
  name                = "autohealing-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10 # 50 seconds

  http_health_check {
    request_path = "/healthz"
    port         = "8080"
  }
}

resource "google_compute_instance_group_manager" "webserver" {
  name = "webserver-igm"

  base_instance_name = "web"
  zone               = "asia-south1-a"

  version {
    instance_template  = google_compute_instance_template.default.id
  }

  all_instances_config {
    metadata = {
      metadata_key = "metadata_value"
    }
    labels = {
      label_key = "label_value"
    }
  }

  target_pools = [google_compute_target_pool.webserver.id]
  target_size  = 2

  named_port {
    name = "customhttp"
    port = 8888
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.autohealing.id
    initial_delay_sec = 300
  }
}

module "lb" {
  source                = "./modules/http-load-balancer"
  name                  = web-lb
  url_map               = google_compute_url_map.urlmap.self_link
  dns_managed_zone_name = ""
  custom_domain_names   = ""
  create_dns_entries    = false
  dns_record_ttl        = true
  enable_http           = true
  enable_ssl            = false
  ssl_certificates      = google_compute_ssl_certificate.certificate.*.self_link
}

resource "google_compute_health_check" "default" {
  name    = "lb-health_checks"

  http_health_check {
    port         = 5000
    request_path = "/api"
  }

  check_interval_sec = 5
  timeout_sec        = 5
}

resource "google_compute_backend_service" "api" {

  name        = "lb-backend"
  description = "API Backend for lb-backend"
  port_name   = "http"
  protocol    = "HTTP"
  timeout_sec = 10
  enable_cdn  = false

  backend {
    group = google_compute_instance_group.webserver.id
  }

  health_checks = [google_compute_health_check.default.self_link]

  depends_on = [google_compute_instance_group.api]
}

resource "google_compute_instance" "vm_instance" {
  name         = "app-instance"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "app-tier"
    access_config {
    }
  }
}

resource "google_compute_instance" "vm_instance" {
  name         = "db-instance"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "db-tier"
    access_config {
    }
  }
}

resource "google_compute_network_peering" "peering1" {
  name         = "peering1"
  network      = google_compute_network.web-tier.self_link
  peer_network = google_compute_network.app-tier.self_link
}

resource "google_compute_network_peering" "peering2" {
  name         = "peering2"
  network      = google_compute_network.app-tier.self_link
  peer_network = google_compute_network.web-tier.self_link
}


resource "google_compute_network_peering" "peering3" {
  name         = "peering3"
  network      = google_compute_network.web-tier.self_link
  peer_network = google_compute_network.db-tier.self_link
}
resource "google_compute_network_peering" "peering4" {
  name         = "peering4"
  network      = google_compute_network.db-tier.self_link
  peer_network = google_compute_network.web-tier.self_link
}

resource "google_compute_network_peering" "peering5" {
  name         = "peering5"
  network      = google_compute_network.app-tier.self_link
  peer_network = google_compute_network.db-tier.self_link
}
resource "google_compute_network_peering" "peering6" {
  name         = "peering6"
  network      = google_compute_network.db-tier.self_link
  peer_network = google_compute_network.app-tier.self_link
}

resource "google_project_iam_policy" "project" {
  project     = "marine-lacing-371009"
  policy_data = data.google_iam_policy.admin.policy_data
}

data "google_iam_policy" "admin" {
  binding {
    role = "roles/compute.instanceAdmin"

    members = [
      "user:pawan.m.363@gmail.com",
    ]
  }
  
  binding {
    role = "roles/compute.objectAdmin"

    members = [
      "user:m36.pawan@gmail.com",
    ]
  }
}

resource "google_compute_firewall" "inbound-ip-ssh-web" {
    name        = "allow-incoming-ssh-from-iap-web"
    network     = "web-tier"

    direction = "INGRESS"
    allow {
        protocol = "tcp"
        ports    = ["22"]  
    }
    source_ranges = [
        "35.235.240.0/20"
    ]
	}

resource "google_compute_firewall" "inbound-ip-ssh-app" {
    name        = "allow-incoming-ssh-from-iap-app"
    network     = "app-tier"

    direction = "INGRESS"
    allow {
        protocol = "tcp"
        ports    = ["22"]  
    }
    source_ranges = [
        "35.235.240.0/20"
    ]
	}
	
resource "google_compute_firewall" "allow-traffic-rule" {
    name        = "allow-incoming-traffic-from-internet"
    network     = "web-tier"

    direction = "INGRESS"
    allow {
        
    source_ranges = [
        "0.0.0.0/0"
    ]
	}