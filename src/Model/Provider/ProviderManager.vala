/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 Leonhard (leo.kargl@proton.me)
 */

public class EmA.ProviderManager : Object {
    private const string ALERT_HUB_PROVIDER_LIST = "https://alert-hub-sources.s3.amazonaws.com/json";

    private ListStore _providers;
    public ListModel providers { get { return _providers; } }

    construct {
        _providers = new ListStore (typeof (Provider));
        //  providers.add (new Germany ());
        //  providers.add (new Ukraine ());
        //  providers.add (new USWeather ());

        load_providers.begin ();
    }

    private async void load_providers () {
        Json.Node json;
        try {
            json = yield Utils.get_json (ALERT_HUB_PROVIDER_LIST);
        } catch (Error e) {
            warning ("Failed to get provider list: %s", e.message);
            return;
        }

        try {
            var root = json.get_object ();
            yield parse_providers (root);
        } catch (Error e) {
            warning ("Failed to parse provider list: %s", e.message);
        }
    }

    private async void parse_providers (Json.Object root) throws Error {
        if (!root.has_member ("sources")) {
            throw new IOError.FAILED ("Missing sources member");
        }

        var sources = root.get_array_member ("sources");

        for (uint i = 0; i < sources.get_length (); i++) {
            var source_container = sources.get_object_element (i);
            var source = source_container.get_object_member ("source");
            yield parse_source (source);
        }
    }

    private async void parse_source (Json.Object source) throws Error {
        if (!source.has_member ("capAlertFeed")) {
            throw new IOError.FAILED ("Missing capAlertFeed member");
        }

        if (!source.has_member ("authorityCountry")) {
            throw new IOError.FAILED ("Missing authorityCountry member");
        }

        var feed_url = source.get_string_member ("capAlertFeed");
        var country_code_str = source.get_string_member ("authorityCountry");
        var country_code = CountryCode.from_string (country_code_str);

        var provider = new RSSProvider (feed_url, country_code);
        _providers.append (provider);
    }
}
