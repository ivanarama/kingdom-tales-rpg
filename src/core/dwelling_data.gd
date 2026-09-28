class_name DwellingData
extends RefCounted

## Жилища для найма существ: id объекта карты -> параметры найма.
## Читается в WorldMapScene._open_dwelling_popup().
## intro форматируется как [в наличии, цена, казна], hire_btn — как [количество, сумма].
## stock_key — ключ в GameState.dwelling_stock (недельный прирост задаёт next_day()).

const DWELLINGS: Dictionary = {
	"fairy_camp": {
		"popup_title": "Роща Волшебных Фей",
		"stock_key": "fairy_camp",
		"unit": "fairy_archer",
		"cost": 30,
		"intro": "Хранительница рощи приветствует героя:\n\n«Мы готовы направить лучниц на службу Королевству!»\n\nДоступно: %d фей-лучниц (по %d золота)\nВ вашей казне: %d золота",
		"hire_btn": "Нанять всех доступных (%d фей за %d зол.)",
		"soldout": "Все феи-лучницы уже наняты на этой неделе!\n\nНовые добровольцы прибудут с началом новой недели."
	},
	"druid_camp": {
		"popup_title": "Круг Болотных Друидов",
		"stock_key": "druid_camp",
		"unit": "druid",
		"cost": 45,
		"intro": "Верховный друид предлагает помощь природы:\n\nДоступно: %d лесных друидов (по %d золота)\nКазна: %d золота",
		"hire_btn": "Нанять отряд (%d друидов за %d зол.)",
		"soldout": "Все друиды уже присоединились к вашему войску на этой неделе!"
	},
	"griffin_nest": {
		"popup_title": "Гнездовье Королевских Грифонов",
		"stock_key": "griffin_nest",
		"unit": "griffin",
		"cost": 65,
		"intro": "Гордые грифоны готовы взмыть в бой:\n\nДоступно: %d грифонов (по %d золота)\nКазна: %d золота",
		"hire_btn": "Нанять грифонов (%d за %d зол.)",
		"soldout": "Все грифоны уже наняты на этой неделе!"
	}
}

static func get_dwelling(obj_id: String) -> Dictionary:
	return DWELLINGS.get(obj_id, {})
