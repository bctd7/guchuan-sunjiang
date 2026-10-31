extends RefCounted
## Shared qualitative cycle; no numeric stress or strength calculation.
const DURATION := 6.0
var elapsed := 0.0
var playing := false
var cycles := 0

func restart() -> void:
	elapsed = 0.0
	cycles = 0
	playing = true

func advance(delta: float) -> void:
	if not playing: return
	var total := elapsed + maxf(0.0,delta)
	cycles += int(floor(total / DURATION))
	elapsed = fposmod(total,DURATION)

func fraction(removable: bool) -> float:
	return smoothstep(.15,1.05,elapsed) * (1.0-smoothstep(4.5,5.9,elapsed))

func touching(removable: bool) -> bool:
	return not removable and elapsed >= 1.05 and elapsed < 4.5

func force_alpha() -> float:
	return smoothstep(.1,1.05,elapsed)*(1.0-smoothstep(4.4,4.8,elapsed))

func pulse() -> float:
	return (elapsed-2.0)/2.25 if elapsed >= 2.0 and elapsed <= 4.25 else -1.0
