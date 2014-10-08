#!/usr/bin/env pike

/*
The MIT License (MIT)

Copyright (c) 2014 Paweł Tomak <pawel@tomak.eu>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/


class Browser(string name, string cmd, array(string) args, string icon)
{
    private array(string) domains = ({ });

    string _sprintf()
    {
        return sprintf("%s(%s, %s)", name, cmd, icon);
    }

    array(string) get_domains() { return domains; }
    void set_domains(array(string) d) { domains = d; }

    string encode_json()
    {
        return Standards.JSON.encode(([ "name": name, "cmd": cmd, "icon": icon, "domains": domains]));
    }

    void open(string url)
    {
        Process.run(({ cmd }) + args + ({ url }));
    }
}

class Config()
{
    array(Browser) browsers = ({ });
    string default_browser = "";
    int x = 0;
    int y = 0;
    mapping(string:string) patterns = ([ ]);
    bool save_position_on_exit = false;

    void create()
    {
        string path = combine_path(getenv("HOME"), ".config", "BrowserPiker.conf");
        if(!Stdio.exist(path))
            return;
        mixed e = catch {
            bool empty(string item) { return !(item && sizeof(item)); };

            mixed conf = Standards.JSON.decode_utf8(Stdio.read_file(path));
            foreach(conf["browsers"], mapping b)
            {
                if(empty(b->name) || empty(b->cmd))
                {
                    werror("Missing name: %O or cmd: %O\n", b->name, b->cmd);
                    continue;
                }
                if( empty(b->icon) )
                    werror("Missing icon for %O\n", b->name);
                array(string) cmd = b->cmd/" ";
                browsers += ({ Browser(b->name, cmd[0], cmd[1..] || ({ }), b->icon) });
                if(!empty(b->domains))
                {
                    browsers[-1]->set_domains(b->domains);
                }
            }
            if(conf["default_browser"] && sizeof(conf["default_browser"]))
                default_browser = conf["default_browser"];
            else
                default_browser = (browsers[0] && browsers[0]->name) || "";
            if(conf["position"] && sizeof(conf["position"]))
            {
                save_position_on_exit = conf["position"]["save_position_on_exit"] || false;
                x = conf["position"]["x"] || 0;
                y = conf["position"]["y"] || 0;
                if(save_position_on_exit)
                {
                    mapping cache = get_position_cache();
                    x = cache->x || x;
                    y = cache->y || y;
                }
            }
        };
        if(e)
        {
            werror("Error while reading config:\n%O\n", e);
            exit(1);
        }
    }

    mapping get_position_cache()
    {
        string cache_path = combine_path(getenv("HOME"), ".cache", "BrowserPiker", "position.json");
        if(Stdio.exist(cache_path))
            mixed e = catch {
                mixed conf = Standards.JSON.decode_utf8(Stdio.read_file(cache_path));
                return conf;
            };

        return ([ ]);
    }

    void set_position_cache(mapping m)
    {
        if(!save_position_on_exit)
            return;
        if(m->x)
            x = m->x;
        if(m->y)
            y = m->y;
    }

    void save_position_cache()
    {
        string cache_path = combine_path(getenv("HOME"), ".cache", "BrowserPiker", "position.json");
        if(Stdio.mkdirhier(dirname(cache_path)) && save_position_on_exit)
            Stdio.write_file(cache_path, Standards.JSON.encode(([ "x": x, "y": y ])));
    }

    string encode_json()
    {
        return Standards.JSON.encode(([ "browsers": browsers, "position": ([ "x": x, "y": y ]), "default_browser": default_browser ]));
    }
}

int main(int argc, array argv)
{
    if( argc != 2 || !sizeof(argv[1]))
        return 1;

    Config conf = Config();

    Standards.URI uri = Standards.URI(argv[1]);

    foreach(conf->browsers, Browser b)
        if(b->get_domains() && sizeof(b->get_domains()) &&
                Array.any(b->get_domains(), glob, uri.host))
        {
            b.open((string)uri);
            return 0;
        }

    argv = GTK2.setup_gtk(argv);
    GTK2.Window toplevel = GTK2.Window( GTK2.WINDOW_TOPLEVEL );
    mapping root_geometry = GTK2.root_window()->get_geometry();
    GTK2.Hbox hbox = GTK2.Hbox(0, 0);
    GTK2.Statusbar status = GTK2.Statusbar();
    int id = status->get_context_id("test");
    status->push(id, sprintf("URL: %s", uri));
    foreach(conf->browsers, Browser b)
    {
        GTK2.Button button = GTK2.Button();
        button->add(GTK2.Image(b->icon));
        button->signal_connect(
            "pressed",
            lambda(mixed widget, mapping args) {
                toplevel->hide_all();
                args["browser"]->open(args["url"]);
                toplevel->signal_emit("destroy"); },
            ([ "browser": b, "url": (string)uri ]));
        hbox->add(button);
        if(b->name == conf->default_browser)
            hbox->set_focus_child(button);
    }
    hbox->signal_connect( GTK2.s_key_press_event, lambda(mixed widget, GTK2.GdkEvent e) {
        if(sscanf(e->data, "%d", int num) == 1)
        {
            if(num > 0 && num <= sizeof(conf->browsers))
                widget->get_children()[num-1]->signal_emit("pressed");
        }
        else if(e->data == "\r")
        {
            foreach(widget->get_children(), GTK2.Widget c)
            {
                if(c->is_focus())
                    c->signal_emit("pressed");
            }
        }
    });
    GTK2.Vbox vbox = GTK2.Vbox(0, 0);
    vbox->add(hbox);
    vbox->add(status);
    toplevel->add(vbox);
    toplevel->signal_connect( "destroy", lambda() { conf->save_position_cache(); exit(0); } );
    toplevel->signal_connect( "event", lambda(mixed widget, GTK2.GdkEvent e) { if(e->type == "configure") conf->set_position_cache(widget->get_position()); });
    toplevel->move(conf->x,conf->y);
    toplevel->show_all();
    toplevel->raise();
    toplevel->activate_focus();
    return -1;
}
