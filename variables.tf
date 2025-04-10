variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (also referred as Cloud API ID)"
  type        = string
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Cloud region"
  type        = string
  default     = "eu-west-1"
}
variable "cloud" {
  description = "Cloud provider"
  type        = string
  default     = "AWS"
}

variable "owner" {
  type = string
  default = "brice@confluent.io"
}

variable "meal_economy_threshold" {
  description = "Economy threshold before raising an alert"
  type        = number
  default = 0.5
}
variable "meal_premium_threshold" {
  description = "Premium threshold before raising an alert"
  type        = number
  default = 1.0
}
variable "meal_business_threshold" {
  description = "Business threshold before raising an alert"
  type        = number
  default = 1.0
}
variable "meal_first_threshold" {
  description = "First class threshold before raising an alert"
  type        = number
  default = 1.0
}
variable "artifact_version" {
  description = "The version is collected in the middle waiting for the artifact resource/data allows access to the version"
  type        = string
  default     = "fail if not overridden"
}
variable "drop_functions" {
  default = false
  type = bool
}





