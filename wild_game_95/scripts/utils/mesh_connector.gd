@tool
extends EditorScript

# Путь к ноде, которую нужно "запечь" — например "ChapaelWall2"
@export var target_path: NodePath = NodePath("ChapaelWall4")

func _run():
	var scene := get_scene()
	var target := scene.get_node(target_path) as MeshInstance3D
	if target == null:
		push_error("Нода не найдена или это не MeshInstance3D: %s" % target_path)
		return

	var st := SurfaceTool.new()
	var result := ArrayMesh.new()

	# собственный меш ноды — трансформ identity относительно себя
	if target.mesh:
		_append(st, result, target.mesh, Transform3D.IDENTITY)

	# все дочерние MeshInstance3D (плейны и т.п.) — с их локальными трансформами
	var to_free: Array[MeshInstance3D] = []
	for child in target.get_children():
		if child is MeshInstance3D and child.mesh:
			_append(st, result, child.mesh, child.transform)
			to_free.append(child)

	target.mesh = result

	for child in to_free:
		child.queue_free()

	print("Done on '%s': %d surfaces" % [target.name, result.get_surface_count()])

func _append(st: SurfaceTool, result: ArrayMesh, mesh: Mesh, xform: Transform3D):
	for surf_idx in mesh.get_surface_count():
		st.clear()
		st.append_from(mesh, surf_idx, xform)
		st.set_material(mesh.surface_get_material(surf_idx))
		st.commit(result)
