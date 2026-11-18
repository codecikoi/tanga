# Sarrof

Нативный iOS-конвертер валют (SwiftUI). *Sarrof* по-узбекски «меняла».

- **Все валюты мира + крипта + металлы:** ~160 фиатных валют, 560+ криптовалют, золото/серебро/платина/палладий. В сумме около 730 кодов.
- **Живые курсы:** автообновление каждую минуту (настраивается: 30 с / 1 мин / 5 мин / вручную), pull-to-refresh, кнопка ⟳ на клавиатуре.
- **Калькулятор в строке:** `650 + 100 × 2` с приоритетом операций, результат сразу во всех валютах.
- **График курса** любой пары: 1Н / 1М / 3М / 1Г / 2Г, Swift Charts, выбор точки пальцем.
- **Офлайн:** последний снимок курсов хранится на диске, а при первом запуске без сети используются курсы, вшитые в сборку.
- Тёмная, светлая и системная тема; русский интерфейс; названия валют на языке устройства.

## Источники данных (бесплатно, без ключей)

| Что | Откуда | Частота |
|---|---|---|
| Живые курсы фиата и крипты | `api.coinbase.com/v2/exchange-rates?currency=USD` | ~1 раз в минуту |
| Список монет: названия, цвета, популярность | `api.coinbase.com/v2/currencies/crypto` | раз в 3 дня |
| 340 валют, металлы, названия | [fawazahmed0/exchange-api](https://github.com/fawazahmed0/exchange-api) (jsDelivr + зеркало pages.dev) | раз в день |
| История для графиков | тот же API, архив `@YYYY-MM-DD` с 2024-03-02 | дневные точки, кэш на диске |
| Флаги | flagcdn.com | кэш на диске |
| Иконки монет | CoinCap, запасной вариант spothq/cryptocurrency-icons | кэш на диске |

**Как сводятся курсы** (`RatesMerger`): за основу берётся дневной Currency API, поверх кладутся живые курсы Coinbase. Крипта всегда из Coinbase. Фиат из Coinbase принимается, только если отличается от дневного не больше чем на 3%: у части редких валют (MNT, SSP) в Coinbase лежат устаревшие значения.

## Структура

```
Sarrof/
  App/            точка входа, настройки
  Domain/         Currency, классификация, калькулятор, форматирование, сведение курсов
  Data/           сеть, репозитории курсов и истории, загрузка иконок
  Features/       Converter (главный экран + клавиатура), Picker, Chart, Settings
  UI/             тема, бейджи флагов и монет
  Resources/Seed/ курсы на момент сборки для офлайн-старта
SarrofTests/      Swift Testing: калькулятор, сведение курсов, каталог, форматирование
Tools/make_icon.swift   генератор иконки (CoreGraphics)
```

Проект на синхронизированных папках Xcode 16+: новые файлы в `Sarrof/` подхватываются без правки `.pbxproj`.

## Запуск

Открыть `Sarrof.xcodeproj` в Xcode 27, схема **Sarrof**. Минимум iOS 18, только iPhone. Команда подписи `82Z8PVTNP5`, bundle id `com.zoir.sarrof`.

```bash
xcodebuild -project Sarrof.xcodeproj -scheme Sarrof -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

Перегенерировать иконку (обычная, тёмная, tinted + логотип):

```bash
swift Tools/make_icon.swift Sarrof/Assets.xcassets
```

Обновить вшитые курсы: заменить JSON в `Sarrof/Resources/Seed/` свежими ответами тех же API.

### Скриншоты из терминала (только Debug)

```bash
xcrun simctl launch booted com.zoir.sarrof -debugActive CNY -debugKeys "650+100*2" -debugRoute chart:USD
```

`-debugKeys`: цифры, `.`, `+ - * /`, `<` (стереть), `C`. `-debugRoute`: `settings`, `add`, `edit`, `replace:XXX`, `chart:XXX`.
