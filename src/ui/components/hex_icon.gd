class_name HexIcon
extends Control
## Crisp runtime vector icons drawn on a 24x24 design grid for MOBA HUD controls.

const DESIGN_SIZE := 24.0

var kind: StringName = &"dot":
	set(value):
		kind = value
		queue_redraw()

var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()

var stroke: float = 2.0:
	set(value):
		stroke = value
		queue_redraw()

var accent: Color = Color.TRANSPARENT:
	set(value):
		accent = value
		queue_redraw()


static func make(icon_kind: StringName, icon_color: Color, pixel_size: float = 22.0,
		icon_stroke: float = 2.0, icon_accent: Color = Color.TRANSPARENT) -> HexIcon:
	var icon := HexIcon.new()
	icon.kind = icon_kind
	icon.color = icon_color
	icon.stroke = icon_stroke
	icon.accent = icon_accent
	icon.custom_minimum_size = Vector2(pixel_size, pixel_size)
	icon.size = Vector2(pixel_size, pixel_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _init() -> void:
	custom_minimum_size = Vector2(22, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 1.0:
		return
	var scale_factor := side / DESIGN_SIZE
	var origin := (size - Vector2(side, side)) * 0.5
	var width := maxf(1.2, stroke * scale_factor)

	match kind:
		&"play": _draw_play(origin, scale_factor, width)
		&"rooms": _draw_signal(origin, scale_factor, width)
		&"signal_bars": _draw_signal_bars(origin, scale_factor)
		&"battery": _draw_battery(origin, scale_factor, width)
		&"swords": _draw_swords(origin, scale_factor, width)
		&"skull": _draw_skull(origin, scale_factor, width)
		&"bot": _draw_bot(origin, scale_factor, width)
		&"hero": _draw_hero(origin, scale_factor, width)
		&"bag": _draw_bag(origin, scale_factor, width)
		&"hammer": _draw_build_glyph(origin, scale_factor, width)
		&"crystal": _draw_crystal(origin, scale_factor, width)
		&"arsenal": _draw_swords(origin, scale_factor, width)
		&"store": _draw_store(origin, scale_factor, width)
		&"coin": _draw_coin(origin, scale_factor, width)
		&"download": _draw_download(origin, scale_factor, width)
		&"mail": _draw_mail(origin, scale_factor, width)
		&"chat": _draw_chat(origin, scale_factor, width)
		&"star": _draw_star(origin, scale_factor, width)
		&"book": _draw_book(origin, scale_factor, width)
		&"chart": _draw_chart(origin, scale_factor, width)
		&"rank": _draw_rank(origin, scale_factor, width)
		&"friends": _draw_people(origin, scale_factor, width)
		&"invite": _draw_invite(origin, scale_factor, width)
		&"profile": _draw_profile(origin, scale_factor, width)
		&"settings": _draw_gear(origin, scale_factor, width)
		&"exit": _draw_exit(origin, scale_factor, width)
		&"plus": _draw_plus(origin, scale_factor, width)
		&"close": _draw_close(origin, scale_factor, width)
		&"check": _draw_check(origin, scale_factor, width)
		&"copy": _draw_copy(origin, scale_factor, width)
		&"refresh": _draw_refresh(origin, scale_factor, width)
		&"lock": _draw_lock(origin, scale_factor, width)
		&"globe": _draw_globe(origin, scale_factor, width)
		&"bolt": _draw_bolt(origin, scale_factor)
		&"shield": _draw_shield(origin, scale_factor, width)
		&"target": _draw_target(origin, scale_factor, width)
		&"chevron": _draw_chevron(origin, scale_factor, width)
		&"share": _draw_share(origin, scale_factor, width)
		&"google": _draw_google(origin, scale_factor)
		&"wifi": _draw_wifi(origin, scale_factor, width)
		&"crown": _draw_crown(origin, scale_factor, width)
		_: _draw_dot(origin, scale_factor, width)


func _p(origin: Vector2, scale_factor: float, x: float, y: float) -> Vector2:
	return origin + Vector2(x, y) * scale_factor


func _poly(origin: Vector2, scale_factor: float, points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(_p(origin, scale_factor, point[0], point[1]))
	return out


func _line(origin: Vector2, scale_factor: float, width: float,
		from: Array, to: Array) -> void:
	draw_line(_p(origin, scale_factor, from[0], from[1]),
		_p(origin, scale_factor, to[0], to[1]), color, width, true)


func _circle(origin: Vector2, scale_factor: float, x: float, y: float,
		radius: float, filled: bool = false, ring_color: Color = Color.TRANSPARENT) -> void:
	var centre := _p(origin, scale_factor, x, y)
	var scaled := radius * scale_factor
	if filled:
		draw_circle(centre, scaled, color)
	elif ring_color.a > 0.0:
		draw_arc(centre, scaled, 0.0, TAU, 32, ring_color, maxf(1.0, stroke * scale_factor), true)


func _tone() -> Color:
	return accent if accent.a > 0.0 else color


func _rect(origin: Vector2, scale_factor: float, x: float, y: float,
		width: float, height: float) -> Rect2:
	return Rect2(_p(origin, scale_factor, x, y), Vector2(width, height) * scale_factor)


func _draw_play(origin: Vector2, scale_factor: float, _width: float) -> void:
	draw_colored_polygon(_poly(origin, scale_factor, [[7, 4], [20, 12], [7, 20]]), color)


func _draw_signal(origin: Vector2, scale_factor: float, width: float) -> void:
	_circle(origin, scale_factor, 5, 19, 1.8, true, Color.TRANSPARENT)
	draw_arc(_p(origin, scale_factor, 5, 19), 5.0 * scale_factor,
		-PI * 0.75, -PI * 0.25, 16, color, width, true)
	draw_arc(_p(origin, scale_factor, 5, 19), 9.0 * scale_factor,
		-PI * 0.75, -PI * 0.25, 16, _tone(), width, true)


func _draw_signal_bars(origin: Vector2, scale_factor: float) -> void:
	var heights := [5.0, 9.0, 13.0, 17.0]
	for idx in 4:
		var h: float = heights[idx]
		var x := 3.5 + float(idx) * 4.8
		draw_rect(_rect(origin, scale_factor, x, 20.0 - h, 3.0, h), color)


func _draw_battery(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_rect(_rect(origin, scale_factor, 2.5, 6.5, 16.5, 11.0), color, false, width)
	draw_rect(_rect(origin, scale_factor, 19.5, 9.5, 2.2, 5.0), color)
	draw_rect(_rect(origin, scale_factor, 5.0, 9.0, 11.5, 6.0), _tone())


func _draw_swords(origin: Vector2, scale_factor: float, width: float) -> void:
	_line(origin, scale_factor, width, [4, 20], [19, 5])
	_line(origin, scale_factor, width, [4.5, 15.5], [8.5, 19.5])
	_line(origin, scale_factor, width, [20, 20], [5, 5])
	_line(origin, scale_factor, width, [15.5, 19.5], [19.5, 15.5])


func _draw_skull(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_arc(_p(origin, scale_factor, 12, 11), 7.5 * scale_factor, PI * 0.85, TAU * 1.08, 24, color, width, true)
	draw_polyline(_poly(origin, scale_factor, [[7, 15], [7, 20], [17, 20], [17, 15]]), color, width, true)
	_circle(origin, scale_factor, 9.5, 11, 1.5, true)
	_circle(origin, scale_factor, 14.5, 11, 1.5, true)


func _draw_bot(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_rect(_rect(origin, scale_factor, 4, 7, 16, 12), color, false, width)
	_line(origin, scale_factor, width, [12, 3], [12, 7])
	_circle(origin, scale_factor, 12, 2.8, 1.4, true)
	_circle(origin, scale_factor, 9, 13, 1.6, true)
	_circle(origin, scale_factor, 15, 13, 1.6, true)


func _draw_hero(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_polyline(_poly(origin, scale_factor, [
		[12, 2.5], [19, 7], [17, 16], [12, 21.5], [7, 16], [5, 7], [12, 2.5],
	]), color, width, true)
	_line(origin, scale_factor, width, [12, 6], [12, 16])
	_line(origin, scale_factor, width, [8.5, 10], [15.5, 10])


func _draw_bag(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_rect(_rect(origin, scale_factor, 4.5, 8.5, 15, 12.5), color, false, width)
	draw_arc(_p(origin, scale_factor, 12, 8.5), 4.0 * scale_factor, PI, TAU, 16, _tone(), width, true)
	_line(origin, scale_factor, width, [4.5, 13.5], [19.5, 13.5])


func _draw_build_glyph(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_polyline(_poly(origin, scale_factor, [[14, 3], [21, 10], [17, 14], [10, 7], [14, 3]]), color, width, true)
	_line(origin, scale_factor, width, [13.5, 10.5], [4, 20])


func _draw_crystal(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_polyline(_poly(origin, scale_factor, [
		[12, 2.5], [19.5, 9], [16, 21], [8, 21], [4.5, 9], [12, 2.5],
	]), color, width, true)
	_line(origin, scale_factor, width * 0.85, [4.5, 9], [19.5, 9])


func _draw_store(origin: Vector2, scale_factor: float, width: float) -> void:
	var body := _poly(origin, scale_factor, [[4, 9], [20, 9], [18.5, 21], [5.5, 21], [4, 9]])
	draw_polyline(body, color, width, true)
	draw_arc(_p(origin, scale_factor, 12, 9), 4.0 * scale_factor, PI, TAU, 16, _tone(), width, true)


func _draw_coin(origin: Vector2, scale_factor: float, width: float) -> void:
	_circle(origin, scale_factor, 12, 12, 8.5, false, color)
	draw_polyline(_poly(origin, scale_factor, [[12, 7.5], [15.5, 12], [12, 16.5], [8.5, 12], [12, 7.5]]), _tone(), width, true)


func _draw_download(origin: Vector2, scale_factor: float, width: float) -> void:
	_line(origin, scale_factor, width, [12, 3.5], [12, 15.5])
	draw_polyline(_poly(origin, scale_factor, [[7.5, 11.5], [12, 16], [16.5, 11.5]]), color, width, true)
	draw_polyline(_poly(origin, scale_factor, [[4, 16.5], [4, 20.5], [20, 20.5], [20, 16.5]]), _tone(), width, true)


func _draw_mail(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_rect(_rect(origin, scale_factor, 3, 5.5, 18, 13), color, false, width)
	draw_polyline(_poly(origin, scale_factor, [[3.5, 6.2], [12, 13], [20.5, 6.2]]), _tone(), width, true)


func _draw_chat(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_polyline(_poly(origin, scale_factor, [
		[4, 5], [20, 5], [20, 16], [11, 16], [6, 20.5], [6, 16], [4, 16], [4, 5],
	]), color, width, true)
	_circle(origin, scale_factor, 9, 10.5, 1.2, true)
	_circle(origin, scale_factor, 12.5, 10.5, 1.2, true)
	_circle(origin, scale_factor, 16, 10.5, 1.2, true)


func _draw_star(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_polyline(_poly(origin, scale_factor, [
		[12, 2.5], [14.7, 8.6], [21.2, 9.3], [16.3, 13.8], [17.7, 20.4],
		[12, 17.0], [6.3, 20.4], [7.7, 13.8], [2.8, 9.3], [9.3, 8.6], [12, 2.5],
	]), color, width, true)


func _draw_book(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_rect(_rect(origin, scale_factor, 4.5, 3.5, 15, 17), color, false, width)
	_line(origin, scale_factor, width, [8.5, 3.5], [8.5, 20.5])
	_line(origin, scale_factor, width, [11.5, 8.5], [16.5, 8.5])
	_line(origin, scale_factor, width, [11.5, 12.5], [16.5, 12.5])


func _draw_chart(origin: Vector2, scale_factor: float, width: float) -> void:
	_line(origin, scale_factor, width, [3.5, 20], [20.5, 20])
	draw_rect(_rect(origin, scale_factor, 5.0, 12.0, 3.5, 8.0), _tone(), false, width)
	draw_rect(_rect(origin, scale_factor, 10.2, 5.5, 3.5, 14.5), color, false, width)
	draw_rect(_rect(origin, scale_factor, 15.5, 9.0, 3.5, 11.0), _tone(), false, width)


func _draw_rank(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_polyline(_poly(origin, scale_factor, [[7, 3], [17, 3], [16, 12]]), color, width, true)
	draw_arc(_p(origin, scale_factor, 12, 12), 4.0 * scale_factor, 0.0, PI, 16, color, width, true)
	_line(origin, scale_factor, width, [12, 16], [12, 20])
	_line(origin, scale_factor, width, [8, 20], [16, 20])
	draw_arc(_p(origin, scale_factor, 6, 7), 3.0 * scale_factor, PI * 0.5, PI * 1.5, 10, _tone(), width, true)
	draw_arc(_p(origin, scale_factor, 18, 7), 3.0 * scale_factor, -PI * 0.5, PI * 0.5, 10, _tone(), width, true)


func _draw_people(origin: Vector2, scale_factor: float, width: float) -> void:
	_circle(origin, scale_factor, 9, 8, 3.4, false, color)
	draw_arc(_p(origin, scale_factor, 9, 19), 6.2 * scale_factor, PI, TAU, 20, color, width, true)
	_circle(origin, scale_factor, 17, 10, 2.6, false, _tone())
	draw_arc(_p(origin, scale_factor, 18, 19), 4.4 * scale_factor, PI * 1.1, TAU * 1.02, 16, _tone(), width, true)


func _draw_invite(origin: Vector2, scale_factor: float, width: float) -> void:
	_circle(origin, scale_factor, 9.5, 8.5, 3.6, false, color)
	draw_arc(_p(origin, scale_factor, 9.5, 20), 6.4 * scale_factor, PI, TAU, 20, color, width, true)
	_line(origin, scale_factor, width, [18.5, 8], [18.5, 15])
	_line(origin, scale_factor, width, [15, 11.5], [22, 11.5])


func _draw_profile(origin: Vector2, scale_factor: float, width: float) -> void:
	_circle(origin, scale_factor, 12, 8, 4.0, false, color)
	draw_arc(_p(origin, scale_factor, 12, 21), 7.5 * scale_factor, PI, TAU, 22, color, width, true)


func _draw_gear(origin: Vector2, scale_factor: float, width: float) -> void:
	_circle(origin, scale_factor, 12, 12, 5.2, false, color)
	_circle(origin, scale_factor, 12, 12, 1.8, true, Color.TRANSPARENT)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var inner := _p(origin, scale_factor, 12, 12) \
			+ Vector2(cos(angle), sin(angle)) * 6.6 * scale_factor
		var outer := _p(origin, scale_factor, 12, 12) \
			+ Vector2(cos(angle), sin(angle)) * 9.4 * scale_factor
		draw_line(inner, outer, color, width, true)


func _draw_exit(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_polyline(_poly(origin, scale_factor, [[4, 3], [12, 3], [12, 6]]), _tone(), width, true)
	draw_polyline(_poly(origin, scale_factor, [[4, 3], [4, 21], [12, 21], [12, 18]]), _tone(), width, true)
	_line(origin, scale_factor, width, [11, 12], [21, 12])
	draw_polyline(_poly(origin, scale_factor, [[18, 8], [22, 12], [18, 16]]), color, width, true)


func _draw_plus(origin: Vector2, scale_factor: float, width: float) -> void:
	_line(origin, scale_factor, width, [12, 4], [12, 20])
	_line(origin, scale_factor, width, [4, 12], [20, 12])


func _draw_close(origin: Vector2, scale_factor: float, width: float) -> void:
	_line(origin, scale_factor, width, [5, 5], [19, 19])
	_line(origin, scale_factor, width, [19, 5], [5, 19])


func _draw_check(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_polyline(_poly(origin, scale_factor, [[4, 13], [10, 19], [20, 5]]), color, width, true)


func _draw_copy(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_rect(_rect(origin, scale_factor, 4, 3, 12, 12), color, false, width)
	draw_rect(_rect(origin, scale_factor, 9, 9, 11, 11), _tone(), false, width)


func _draw_refresh(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_arc(_p(origin, scale_factor, 12, 12), 7.5 * scale_factor,
		-PI * 0.35, PI * 1.1, 24, color, width, true)
	draw_polyline(_poly(origin, scale_factor, [[16, 3], [20, 7], [15, 9]]), color, width, true)


func _draw_lock(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_arc(_p(origin, scale_factor, 12, 10), 4.6 * scale_factor, PI, TAU, 18, color, width, true)
	draw_rect(_rect(origin, scale_factor, 5, 10, 14, 10), color, false, width)


func _draw_globe(origin: Vector2, scale_factor: float, width: float) -> void:
	_circle(origin, scale_factor, 12, 12, 9.0, false, color)
	draw_line(_p(origin, scale_factor, 12, 3), _p(origin, scale_factor, 12, 21), _tone(), width, true)
	draw_line(_p(origin, scale_factor, 3.6, 8.6), _p(origin, scale_factor, 20.4, 8.6), _tone(), width * 0.8, true)
	draw_line(_p(origin, scale_factor, 3.6, 15.4), _p(origin, scale_factor, 20.4, 15.4), _tone(), width * 0.8, true)


func _draw_bolt(origin: Vector2, scale_factor: float) -> void:
	draw_colored_polygon(_poly(origin, scale_factor, [[13, 2], [5, 14], [11, 14], [9, 22], [19, 9], [13, 9]]), color)


func _draw_shield(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_polyline(_poly(origin, scale_factor, [
		[12, 2], [20, 6], [20, 12], [12, 22], [4, 12], [4, 6], [12, 2],
	]), color, width, true)


func _draw_target(origin: Vector2, scale_factor: float, width: float) -> void:
	_circle(origin, scale_factor, 12, 12, 9.0, false, color)
	_circle(origin, scale_factor, 12, 12, 3.6, false, _tone())
	_line(origin, scale_factor, width, [12, 1], [12, 6])
	_line(origin, scale_factor, width, [12, 18], [12, 23])
	_line(origin, scale_factor, width, [1, 12], [6, 12])
	_line(origin, scale_factor, width, [18, 12], [23, 12])


func _draw_chevron(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_polyline(_poly(origin, scale_factor, [[9, 5], [16, 12], [9, 19]]), color, width, true)


func _draw_share(origin: Vector2, scale_factor: float, width: float) -> void:
	_circle(origin, scale_factor, 6, 12, 3.0, false, color)
	_circle(origin, scale_factor, 18, 5, 3.0, false, _tone())
	_circle(origin, scale_factor, 18, 19, 3.0, false, _tone())
	_line(origin, scale_factor, width * 0.8, [9, 11], [15, 6.5])
	_line(origin, scale_factor, width * 0.8, [9, 13], [15, 17.5])


func _draw_google(origin: Vector2, scale_factor: float) -> void:
	const BLUE := Color("4285f4")
	const GREEN := Color("34a853")
	const YELLOW := Color("fbbc05")
	const RED := Color("ea4335")
	var centre := _p(origin, scale_factor, 12, 12)
	var radius := 8.4 * scale_factor
	var thickness := 3.4 * scale_factor
	draw_arc(centre, radius, deg_to_rad(-38.0), deg_to_rad(38.0), 20, BLUE, thickness, true)
	draw_arc(centre, radius, deg_to_rad(38.0), deg_to_rad(150.0), 24, GREEN, thickness, true)
	draw_arc(centre, radius, deg_to_rad(150.0), deg_to_rad(215.0), 20, YELLOW, thickness, true)
	draw_arc(centre, radius, deg_to_rad(215.0), deg_to_rad(322.0), 24, RED, thickness, true)
	draw_line(_p(origin, scale_factor, 12.2, 12.0),
		_p(origin, scale_factor, 20.4, 12.0), BLUE, thickness, true)


func _draw_wifi(origin: Vector2, scale_factor: float, width: float) -> void:
	_circle(origin, scale_factor, 12, 19, 1.7, true, Color.TRANSPARENT)
	for index in 3:
		var radius := (5.0 + float(index) * 4.0) * scale_factor
		draw_arc(_p(origin, scale_factor, 12, 19), radius,
			-PI * 0.78, -PI * 0.22, 20, color.lerp(Color(1, 1, 1, 0.0), float(index) * 0.22),
			width, true)


func _draw_crown(origin: Vector2, scale_factor: float, width: float) -> void:
	draw_polyline(_poly(origin, scale_factor, [
		[3, 18], [5, 6], [9.5, 12], [12, 4], [14.5, 12], [19, 6], [21, 18], [3, 18],
	]), color, width, true)


func _draw_dot(origin: Vector2, scale_factor: float, _width: float) -> void:
	_circle(origin, scale_factor, 12, 12, 3.5, true, Color.TRANSPARENT)
