# Unixgram iOS Fork v0.6 — BUILD READY

В этой версии уже подготовлена сборка unsigned IPA через GitHub Actions.

Что внутри:
- SwiftUI-проект Unixgram;
- новая иконка приложения;
- `project.yml` для XcodeGen;
- `.github/workflows/build-ipa.yml`;
- упаковка готового `.app` в `Unixgram-unsigned.ipa`.

## Как получить IPA с Windows

1. Создай пустой GitHub-репозиторий.
2. Распакуй этот архив.
3. Загрузи **всё содержимое** архива в корень репозитория.
4. Проверь, что в репозитории есть `.github/workflows/build-ipa.yml`.
5. Открой `Actions`.
6. Выбери `Build unsigned IPA`.
7. Нажми `Run workflow`.
8. После завершения скачай artifact `Unixgram-iOS-v0.6-unsigned-IPA`.
9. Внутри будет `Unixgram-unsigned.ipa`.

Unsigned IPA затем нужно подписать перед установкой на iPhone — например, через AltStore/SideStore/Sideloadly или собственной developer-подписью.

Если GitHub Actions покажет красную ошибку, скачай artifact `xcode-build-log` и пришли его мне — исправим точечно.

Важно: текущий проект всё ещё является UI-прототипом. Реальные серверные действия Unixgram подключаются отдельно через подтверждённые API/UnixProto методы.
