bucket_name = "stackew"
vpc_cidr_block = "10.0.0.0/16"
subnet_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24", "10.0.40.0/24"]
tags = ["Psb1", "Psb2", "Appsb1", "Appsb2", "DBsb1", "DBsb2"]
zones = ["ap-south-1a", "ap-south-1b", "ap-south-1a","ap-south-1b", "ap-south-1a", "ap-south-1b"]
map_public_ip = ["true", "true", "false", "false", "false", "false"]
masterdb_identifier = "master-db-instance"
db_storage_type = "gp2"
db_engine = "mysql"
db_engine_version = "5.7"
db_instance_class = "db.t2.micro"
db_subnet_group_description = "DB Subnet Group"
masterdb_name = "mydb"
masterdb_username = "admin"
masterdb_password = "Kittu!54321" 
replicadb_identifier = "replica-db-instance"