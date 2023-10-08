module "vpc_modules" {
  source     = "./modules/aws_vpc"
  for_each   = var.vpc_config
  cidr_block = each.value.cidr_block
  tags       = each.value.tags

}

module "aws_subnets" {
  source   = "./modules/aws_subnets"
  for_each = var.subnet_config

  availability_zone = each.value.availability_zone
  vpc_id            = module.vpc_modules[each.value.vpc_name].vpc_id
  cidr_block        = each.value.cidr_block
  tags              = each.value.tags

}

module "internetGW_module" {
  source   = "./modules/aws_internetGW"
  for_each = var.internetGW_config
  vpc_id   = module.vpc_modules[each.value.vpc_name].vpc_id
  tags     = each.value.tags
}

module "natGW_module" {
  source    = "./modules/aws_natGW"
  for_each  = var.natGW_config
  subnet_id = module.aws_subnets[each.value.subnet_name].subnet_id
  elasticIP = module.eip_module[each.value.eip_name].eip_nat
  tags      = each.value.tags

}

module "eip_module" {
  source   = "./modules/elastic_IP"
  for_each = var.eip_config
  tags     = each.value.tags
}

module "route_table" {
  source                  = "./modules/aws_route_table"
  for_each                = var.route_table_config
  aws_internet_gateway_id = each.value.private == 0 ? module.internetGW_module[each.value.gateway_name].internet_gateway_id : module.natGW_module[each.value.gateway_name].aws_nat_gateway_id
  vpc_id                  = module.vpc_modules[each.value.vpc_name].vpc_id
  tags                    = each.value.tags

}

module "route_table_assosiation" {
  source         = "./modules/aws_route_table_assosiation"
  for_each       = var.route_table_assosiation
  subnet_id      = module.aws_subnets[each.value.subnet_name].subnet_id
  route_table_id = module.route_table[each.value.route_table_name].route_table_id
}

module "aws_eks" {
  source     = "./modules/aws_eks"
  for_each   = var.eks_cluster
  eks_name   = each.value.eks_cluster_name
  subnet_ids = [module.aws_subnets[each.value.subnet1].subnet_id, module.aws_subnets[each.value.subnet2].subnet_id, module.aws_subnets[each.value.subnet3].subnet_id, module.aws_subnets[each.value.subnet4].subnet_id]
  tags       = each.value.tags
}

module "aws_eks_nodegroup" {
  source          = "./modules/aws_eks_nodegroup"
  for_each        = var.aws_eks_nodegroup
  eks_name        = module.aws_eks[each.value.eks_cluster_name].eks_cluster_name
  subnet_ids      = [module.aws_subnets[each.value.subnet1].subnet_id, module.aws_subnets[each.value.subnet2].subnet_id]
  node_group_name = each.value.node_group_name
  node_iam_role   = each.value.node_iam_role
  tags            = each.value.tags
}