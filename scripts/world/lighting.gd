class_name Lighting
extends Node3D
## Sky, sun, fog and post. Warm sun + cool ambient + haze = cheap depth. Stylized, not realistic.

var env := Environment.new()


func _init() -> void:
	name = "Lighting"
	var horizon := Color(0.76, 0.8, 0.84)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.26, 0.46, 0.78)
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = Color(0.4, 0.42, 0.4)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.63, 0.8)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.2
	env.fog_enabled = true
	env.fog_light_color = horizon
	env.fog_density = 0.00005
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.35
	env.fog_sun_scatter = 0.15
	# Forward+ only: contact shadows in corners/under cars. Off by default - even the
	# cheapest mode costs ~6 ms/frame on the M1 at Retina res. F3 toggles it.
	env.ssao_enabled = false
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.5
	env.ssao_power = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)


func toggle_ao() -> void:
	env.ssao_enabled = not env.ssao_enabled
