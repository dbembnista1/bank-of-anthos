variable "domain" {
  description = "Existing public hosted zone name (e.g. example.com). Looked up, never created or destroyed by this module. ACM cert is issued in this stack."
  type        = string
}
