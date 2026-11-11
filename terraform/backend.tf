terraform {
  backend "local" {
    # Local state file is ignored by the repository .gitignore.
    path = "terraform.tfstate"
  }
}
