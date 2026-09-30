# Тесты

Весь набор запускается одной сценой с автозагрузками `res://tests/test_runner.tscn` — так же, как в CI (`.github/workflows/tests.yml`) и в `run_tests.bat`. Успех — строка `ALL N TEST SUITES PASSED` и ни одного `SCRIPT ERROR` / `Assertion failed` в логе.

## Новый набор — отдельным файлом

Наборы 1–76 записаны прямо в `_ready()` раннера. Новые кладите файлом в `tests/suites/`:

```gdscript
extends RefCounted
## Что проверяет набор (одной строкой).

const TITLE := "Testing Something Important"


func run(t: Node) -> void:
	GameState.reset()
	var wm = load("res://src/world/world_map.tscn").instantiate()
	t.add_child(wm)
	await t.get_tree().process_frame
	assert(wm.hero_relics_lbl != null, "Hero relics label must exist")
	wm.queue_free()
	await t.get_tree().process_frame
	GameState.reset()
	print("  -> Something important verified!")
```

- `t` — узел раннера: `t.add_child(...)`, `await t.get_tree().process_frame`, помощники раннера вроде `t._has_cyrillic(...)`.
- Строку `[TEST] N. …` и итоговый счётчик печатает раннер. Номер идёт по алфавиту файлов, вписывать его не нужно. Поэтому два PR с новыми тестами больше не конфликтуют в хвосте `test_runner.gd`.
- Набор не должен зависеть от порядка: начинайте и заканчивайте его `GameState.reset()`, свои узлы освобождайте.

## Сторож и seed

- Упавший `assert` останавливает прогон. Если прогон не закончился за `WATCHDOG_SEC` (240 с), раннер печатает `TEST WATCHDOG` и выходит с кодом 1. Упавший набор — последняя строка `[TEST]` перед этим сообщением.
- В начале прогона вызывается `seed(TEST_SEED)`, поэтому случайные броски одинаковы в каждом прогоне. Если тест проходит только при удачном броске, чините тест, а не seed: так, проверка ослепления в наборе 74 даёт цели 200 гоблинов, чтобы удар единорогов их не вырезал.
