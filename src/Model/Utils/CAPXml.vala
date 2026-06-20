/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Leonhard (leo.kargl@proton.me)
 */

namespace EmA.CAP {
    public void fill_warning_details_from_alert_xml (Warning warn, Xml.Node* alert) {
        assert (alert->name == "alert");

        for (Xml.Node* iter = alert->children; iter != null; iter = iter->next) {
            parse_alert_child (warn, iter);
        }
    }

    private void parse_alert_child (Warning warn, Xml.Node* node) {
        if (node->name == "id") {
            if (warn.id != get_text (node)) {
                warning ("Warning ID mismatch between CAP alert and Warning object");
            }
        }

        if (node->name == "sender") {
            warn.sender_id = get_text (node);
        }

        if (node->name == "sent") {
            var sent_str = get_text (node);
            warn.sent = new DateTime.from_iso8601 (sent_str, null);
        }

        if (node->name == "status") {
            var status = get_text (node);
            if (status != "Actual") {
                warning ("Only 'actual' status should be presented to the user");
            }
        }

        //  if (alert.has_member ("msgType")) {
        //      // TODO: Do we want to use this information?
        //  }

        if (node->name == "scope") {
            var scope = get_text (node);
            if (scope != "Public") {
                warning ("Non-public CAP alerts should not be presented to the user");
            }
        }

        if (node->name == "info") {
            fill_warning_details_from_info_xml (warn, node);
        }
    }

    public void fill_warning_details_from_info_xml (Warning warn, Xml.Node* info) {
        assert (info->name == "info");

        for (Xml.Node* iter = info->children; iter != null; iter = iter->next) {
            parse_info_child (warn, iter);
        }
    }

    private void parse_info_child (Warning warn, Xml.Node* node) {
        if (node->name == "event") {
            warn.event = get_text (node);
        }

        if (node->name == "headline") {
            warn.title = get_text (node);
        }

        if (node->name == "description") {
            warn.description = get_text (node);
        }

        if (node->name == "instruction") {
            warn.instruction = get_text (node);
        }
    }

    private string? get_text (Xml.Node* element_node) {
        if (element_node->type != ELEMENT_NODE) {
            return null;
        }

        if (element_node->children == null || element_node->children->type != TEXT_NODE) {
            return null;
        }

        return element_node->children->get_content ();
    }
}
