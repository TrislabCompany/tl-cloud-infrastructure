# Rotates the state passphrase (08-pipeline.md section 7, Encryption; ADR 0046).
# OpenTofu writes a state only when it changes, so each rotation sets input to
# its month, and the apply writes this root's state under the next passphrase.
resource "terraform_data" "encryption" {
  input = "2026-10"
}
