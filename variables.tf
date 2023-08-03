variable "region" {
    type = string
    default = "ap-south-1"
}

variable "bucket_name" {
    type = string
}

variable "vpc_cidr_block" {
    type = string
}


variable "map_public_ip" {
  type = list(string)
}

variable "subnet_cidr_blocks" {
  type        = list(string)
}

variable "tags" {
  type        = list(string) 
}

variable "zones" {
  type        = list(string)
  default = [ "ap-south-1a", "ap-south-1b" ]
}

variable "masterdb_identifier" {
  type        = string
}

variable "db_engine" {
  type        = string
}

variable "db_storage_type" {
  type        = string
}

variable "db_engine_version" {
  type        = string
  default = "5.7"
}

variable "db_instance_class" {
  type        = string
}

variable "db_subnet_group_description" {
  type = string
}


variable "masterdb_name" {
  type = string
}

variable "masterdb_username" {
  type = string
}

variable "masterdb_password" {
  type = string
}

variable "replicadb_identifier" {
  type        = string
}