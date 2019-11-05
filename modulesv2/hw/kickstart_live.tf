##
## LiveOS base template renderer
##

resource "matchbox_profile" "ks-live" {
  name           = "live"
  generic_config = "{{.config}}"
}

resource "matchbox_group" "ks-live" {
  for_each = var.live_hosts

  profile = matchbox_profile.ks-live.name
  name    = each.key
  selector = {
    ks = each.key
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/kickstart/live.ks.tmpl", {
    })
  }
}