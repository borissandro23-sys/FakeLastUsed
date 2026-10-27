# FakeLastUsed

Подмена **«Последнее использование»** в **Настройки → Основные → Хранилище iPhone** (iOS 15, rootless / Dopamine).

## Пункт в «Настройках»

После установки (нужен **PreferenceLoader**):

**Настройки → FakeLastUsed**

- Включено  
- Режим: Только что / Не использовалось / Фикс. дата  
- Поле даты ISO-8601  
- Отладка  

## Режимы

| Mode | Эффект |
|------|--------|
| `justnow` | Только что |
| `never` | Не использовалось |
| `fixed` | Дата из поля FixedDate |

## Сборка

```bash
export THEOS=~/theos
export THEOS_PACKAGE_SCHEME=rootless
make package FINALPACKAGE=1
```

## После смены настроек

Закройте приложение «Настройки» полностью и откройте снова (или `killall Preferences`).

## Важно

Имена хуков Storage проверьте на 15.8.8 через FLEX/class-dump. Меняется только UI хранилища.
