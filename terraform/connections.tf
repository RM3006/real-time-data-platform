# Fichier: terraform/connections.tf
# Gère la connexion sécurisée entre AWS et GitHub

resource "aws_codestarconnections_connection" "github_connection" {
  provider_type = "GitHub"
  name          = "rt-platform-github-connection"
}