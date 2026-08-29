defmodule AshPhoenixStarter.Cldr do
  use Cldr,
    locales: ["en"],
    default_locale: "en",
    gettext: AshPhoenixStarterWeb.Gettext,
    providers: [
      Cldr.Number,
      Cldr.Calendar,
      Cldr.DateTime,
      Cldr.Territory,
      Cldr.Unit,
      Cldr.List,
      Cldr.LocaleDisplay,
      Cldr.Routes
    ]
end
