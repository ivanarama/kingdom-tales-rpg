# Наборы тестов

`tests/test_runner.tscn` запускает все `*.gd` из этой папки по алфавиту после основных наборов.
Каждая фича кладёт свои проверки в отдельный файл — так PR не конфликтуют в `test_runner.gd`.

```gdscript
extends RefCounted

func get_title() -> String:  # необязательно
	return "Что проверяем"

func run(t) -> void:  # t — раннер: t._check(условие, "сообщение"), t.add_child(узел), t.get_tree()
	t._check(1 + 1 == 2, "арифметика")
	await t.get_tree().process_frame  # можно ждать
```

Провал `_check`, `SCRIPT ERROR` или `push_error` во время набора валят весь прогон (код выхода 1).
