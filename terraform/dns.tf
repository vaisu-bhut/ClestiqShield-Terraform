# Reserve static IP for the Gateway
resource "google_compute_address" "gateway_ip" {
  name   = "${var.application_name}-${var.environment}-gateway-ip"
  region = var.region
}

# DNS Zone Data Source
data "google_dns_managed_zone" "shield_zone" {
  name = "clestiq-shield"
}

# Create A Record
resource "google_dns_record_set" "api" {
  name = "api.${data.google_dns_managed_zone.shield_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.shield_zone.name

  rrdatas = [google_compute_address.gateway_ip.address]
}
