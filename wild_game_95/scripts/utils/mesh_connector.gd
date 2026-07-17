@tool
extends EditorScript

func _run():
	var scene := get_scene()  # текущая открытая сцена в редакторе
	var wall5 := scene.get_node("WallTile5") as MeshInstance3D
	var m1 := scene.get_node("WallTile5/MeshInstance3D") as MeshInstance3D
	var m2 := scene.get_node("WallTile5/MeshInstance3D2") as MeshInstance3D

	var st := SurfaceTool.new()
	var result := ArrayMesh.new()

	# бокс — в локальном пространстве WallTile5, трансформ identity относительно себя
	_append(st, result, wall5.mesh, Transform3D.IDENTITY)
	# плейны — с их локальными трансформами относительно WallTile5
	_append(st, result, m1.mesh, m1.transform)
	_append(st, result, m2.mesh, m2.transform)

	wall5.mesh = result

	# чистим — геометрия уже внутри result
	m1.queue_free()
	m2.queue_free()

	print("Done: ", result.get_surface_count(), " surfaces")

func _append(st: SurfaceTool, result: ArrayMesh, mesh: Mesh, xform: Transform3D):
	for surf_idx in mesh.get_surface_count():
		st.clear()
		st.append_from(mesh, surf_idx, xform)
		st.set_material(mesh.surface_get_material(surf_idx))
		st.commit(result)
