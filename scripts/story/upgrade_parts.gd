extends RefCounted

const TYPES := ["", "Loader", "Armor", "Bank Shot", "Engine"]
const DESCRIPTIONS := {
	"Loader": "Faster reload (0.22s).",
	"Armor": "Four armor points; slightly slower movement.",
	"Bank Shot": "One extra bounce; bank shots deal two damage.",
	"Engine": "Faster movement; two armor points.",
}
const COLORS := {"Loader": Color("ffe600"), "Armor": Color("00dfd0"), "Bank Shot": Color("ff1493"), "Engine": Color("7cf4bc")}

static func sanitize(values: Array) -> Array[String]:
	var result: Array[String] = []
	for i in range(4):
		var value := str(values[i]) if i < values.size() else ""
		result.append(value if TYPES.has(value) else "")
	return result
