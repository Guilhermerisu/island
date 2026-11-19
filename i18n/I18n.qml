pragma Singleton
import QtQuick
import "Translations.js" as Catalog

QtObject {
  property string language: "auto"
  readonly property string effectiveLanguage: language === "auto"
    ? (Qt.locale().name.indexOf("ru") === 0 ? "ru" : "en") : language === "ru" ? "ru" : "en"
  readonly property string localeName: effectiveLanguage === "ru" ? "ru_RU" : "en_US"
  function tr(source) { return Catalog.translate(source, effectiveLanguage) }
  function menuEntry(entry) { return Catalog.menuEntry(entry) }
  function appEntry(entry) { return Catalog.appEntry(entry) }
  function normalize(value) { return Catalog.normalize(value) }
}
