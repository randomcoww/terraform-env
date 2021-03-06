##
## Render README
##
resource "local_file" "readme" {
  content = templatefile("./templates/README.tmpl", {
    secrets_file     = "secrets.tfvars"
    users            = local.aggr_users
    container_images = local.container_images
    hypervisor_hosts = {
      for k in local.components.hypervisor.nodes :
      k => local.aggr_hosts[k]
    }
  })
  filename = "../README.md"
}