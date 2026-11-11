terraform {
  backend "local" {
    # State is intentionally local and must never be committed.
    path = "terraform.tfstate"
  }
}
