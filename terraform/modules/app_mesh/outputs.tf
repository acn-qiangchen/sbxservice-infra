output "mesh_id" {
  description = "The ID of the App Mesh service mesh"
  value       = aws_appmesh_mesh.service_mesh.id
}

output "mesh_name" {
  description = "The name of the App Mesh service mesh"
  value       = aws_appmesh_mesh.service_mesh.name
}

output "virtual_node_name" {
  description = "The name of the App Mesh virtual node"
  value       = aws_appmesh_virtual_node.service.name
}

output "virtual_service_name" {
  description = "The name of the App Mesh virtual service"
  value       = aws_appmesh_virtual_service.service.name
} 