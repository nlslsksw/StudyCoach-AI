#!/bin/zsh
# Demo-Simulatoren für Screenshots & Videos (Debug-Build mit Demo-Daten).
#
#   ./demo.sh              baut die App und startet Kind + Eltern
#   ./demo.sh shot NAME    macht von beiden Simulatoren Screenshots → docs/screenshots/NAME-*.png
#   ./demo.sh rec kind     nimmt ein Video vom Kind-Simulator auf (Strg+C beendet) → docs/screenshots/
#   ./demo.sh rec eltern   dito für Eltern
#
# Tabs beim Kind vorwählen: ./demo.sh tab 2   (0 Heute, 1 Kalender, 2 Fächer, 3 Statistik)

set -e
cd "$(dirname "$0")"
KIND=2912A963-B594-4DBB-A27E-603488B9E66C      # "Kind – Nils (iPhone 17 Pro)"
ELTERN=A2EF2A7B-98C3-4D2D-A48B-9F8A9203578E    # "Eltern (iPhone 17 Pro)"
BUNDLE=Ralf-Lohrmann.Lern-Kalender
OUT=docs/screenshots

boot() {
  for D in $KIND $ELTERN; do xcrun simctl boot $D 2>/dev/null || true; done
  open -a Simulator 2>/dev/null || open -b com.apple.iphonesimulator 2>/dev/null || true
  sleep 5
  for D in $KIND $ELTERN; do
    xcrun simctl status_bar $D override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
  done
}

build_install() {
  xcodebuild -project "Lern Kalender.xcodeproj" -scheme "Lern Kalender" \
    -destination "platform=iOS Simulator,id=$KIND" build 2>&1 | grep -E "error:|BUILD"
  APP=$(find ~/Library/Developer/Xcode/DerivedData -path "*Lern_Kalender*" -path "*Debug-iphonesimulator*" -maxdepth 6 -name "Lern Kalender.app" | head -1)
  for D in $KIND $ELTERN; do xcrun simctl install $D "$APP"; done
}

launch() {
  xcrun simctl terminate $KIND $BUNDLE 2>/dev/null || true
  xcrun simctl terminate $ELTERN $BUNDLE 2>/dev/null || true
  xcrun simctl launch $KIND $BUNDLE -demo student -tab "${1:-0}" >/dev/null
  xcrun simctl launch $ELTERN $BUNDLE -demo parent >/dev/null
}

case "${1:-start}" in
  start) boot; build_install; launch 0; echo "Kind + Eltern laufen." ;;
  tab)   launch "$2" ;;
  shot)  mkdir -p $OUT; sleep 1
         xcrun simctl io $KIND screenshot "$OUT/${2:-shot}-kind.png" >/dev/null
         xcrun simctl io $ELTERN screenshot "$OUT/${2:-shot}-eltern.png" >/dev/null
         echo "→ $OUT/${2:-shot}-kind.png, $OUT/${2:-shot}-eltern.png" ;;
  rec)   mkdir -p $OUT; D=$KIND; [[ "$2" == "eltern" ]] && D=$ELTERN
         F="$OUT/video-${2:-kind}-$(date +%H%M%S).mp4"
         echo "Aufnahme läuft → $F   (Strg+C zum Beenden)"
         xcrun simctl io $D recordVideo --codec h264 "$F" ;;
  *)     sed -n 2,10p "$0" ;;
esac
