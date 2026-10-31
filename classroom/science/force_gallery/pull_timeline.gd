extends RefCounted
## A single blocked in-plane pull. Motion is only existing assembly clearance.
## This timing illustrates a tug/release, not a computed elastic deformation.
var DURATION := 6.0
var lead := .35
var elapsed := 0.0
var playing := false
var cycles := 0

func configure(has_cutaway: bool) -> void:
	DURATION = 7.2 if has_cutaway else 6.0
	lead = 1.4 if has_cutaway else .35

func restart() -> void:
	elapsed = 0.0
	cycles = 0
	playing = true

func advance(delta: float) -> void:
	if not playing: return
	var total := elapsed+maxf(delta,0.0)
	cycles += int(floor(total/DURATION))
	elapsed = fposmod(total,DURATION)

func fraction(_removable: bool) -> float:
	var t := elapsed-lead
	var amount := smoothstep(.1,1.05,t)*(1.0-smoothstep(3.6,4.5,t))
	# A small return bounce stays inside the independently swept safe interval.
	if t > 4.5 and t < 4.9:
		amount = .13*pow(sin(PI*(t-4.5)/.4),2)
	return clampf(amount,0.0,1.0)

func touching(_removable: bool) -> bool:
	var t := elapsed-lead
	return t >= 1.05 and t <= 3.6

func force_alpha() -> float:
	var t := elapsed-lead
	return smoothstep(.05,1.05,t)*(1.0-smoothstep(3.15,3.6,t))

func reaction_alpha() -> float:
	return force_alpha()*smoothstep(1.05,1.22,elapsed-lead) if touching(false) else 0.0

func contact_alpha() -> float:
	if not touching(false): return 0.0
	var t := elapsed-lead-1.05
	return (.6+.4*exp(-3.0*t))*reaction_alpha()

func pulse() -> float:
	return -1.0

func cutaway_alpha() -> float:
	return smoothstep(.3,1.3,elapsed)*(1.0-smoothstep(6.35,7.05,elapsed))
