extends RefCounted
## Two pulls share one fixed section view. Each rail returns before handover.
## fraction never exceeds the verified clearance interval.
const DURATION := 13.2
const STAGE := 5.5
const LEAD := 1.1
var elapsed := 0.0
var playing := false
var cycles := 0

func restart() -> void:
	elapsed = 0.0
	cycles = 0
	playing = true

func advance(delta: float) -> void:
	if not playing: return
	var total := elapsed+maxf(0.0,delta)
	cycles += int(floor(total/DURATION))
	elapsed = fposmod(total,DURATION)

func stage_time() -> float:
	return clampf(elapsed-LEAD,0.0,2.0*STAGE)

func mode_index() -> int:
	return 0 if stage_time() < STAGE else 1

func local_time() -> float:
	return stage_time()-STAGE*mode_index()

func fraction(_removable := false) -> float:
	var t := local_time()
	var travel := smoothstep(.20,1.20,t)*(1.0-smoothstep(3.1,4.15,t))
	# Bounded return settling, on the free side of the same contact wall.
	if t > 4.15 and t < 4.75:
		travel = .28*pow(sin(PI*(t-4.15)/.60),2)
	return clampf(travel,0.0,1.0)

func touching(_removable := false) -> bool:
	return local_time() >= 1.20 and local_time() <= 3.1

func force_alpha() -> float:
	var t := local_time()
	return smoothstep(.10,1.20,t)*(1.0-smoothstep(2.65,3.1,t))

func reaction_alpha() -> float:
	return force_alpha()*smoothstep(1.20,1.38,local_time()) if touching() else 0.0

func cutaway_alpha() -> float:
	# The cut remains open through both loads; restoration occurs at zero travel.
	return smoothstep(.10,.95,elapsed)*(1.0-smoothstep(12.25,13.05,elapsed))
