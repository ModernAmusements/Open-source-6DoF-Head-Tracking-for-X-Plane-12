⸻

🎯 Goal
	•	Keep screen centered
	•	Still reach ~90° view left/right

⸻

🧠 Solution (math)

Map real head angle → virtual camera angle using a non-linear curve:

virtual_yaw = f(real_yaw)


⸻

⚙️ Practical setup
	•	Real head ≈ ±30°
	•	Virtual view ≈ ±90°

Example mapping:

Head	View
0°	0°
10°	15°
20°	50°
30°	90°


⸻

✅ Key idea
	•	Small movement → precise (center stable)
	•	Larger movement → accelerated turning

⸻


⸻

🔑 Extras
	•	Add deadzone (~2–3°) for stability
	•	Optional: slight recentering bias

⸻

👉 In short:
It’s a non-linear scaling problem, not just angles.