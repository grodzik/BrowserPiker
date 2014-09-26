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


class Browser(string name, string path, string icon)
{
    private array(string) domains = ({ });

    string _sprintf()
    {
        return sprintf("%s(%s, %s)", name, path, icon);
    }

    array(string) get_domains() { return domains; }
    void set_domains(array(string) d) { domains = d; }

    string encode_json()
    {
        return sprintf("{\n\"name\": \"%s\",\n\"path\": \"%s\",\n\"icon\": \"%s\"\n}", name, path, icon);
    }

    void open(string url)
    {
        Process.run(({ path, url }));
    }
}

class Config()
{
    array(Browser) browsers = ({ });
    string default_browser = "";
    int x = 0;
    int y = 0;
    mapping(string:string) patterns = ([ ]);

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
                if(empty(b->name) || empty(b->path))
                {
                    werror("Missing name: %O or path: %O\n", b->name, b->path);
                    continue;
                }
                if( empty(b->icon) )
                    werror("Missing icon for %O\n", b->name);
                browsers += ({ Browser(b->name, b->path, b->icon) });
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
                x = conf["position"]["x"] || 0;
                y = conf["position"]["y"] || 0;
            }
        };
        if(e)
        {
            werror("Error while reading config:\n%O\n", e);
            exit(1);
        }
    }

    string encode_json()
    {
        return sprintf("\"browsers\":\n%s\n", Standards.JSON.encode(browsers->encode_json()));
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
    foreach(conf->browsers, Browser b)
    {
        GTK2.Button button = GTK2.Button();
        button->add(GTK2.Image(b->icon));
        button->signal_connect(
            "pressed",
            lambda(mixed widget, string url) {
                toplevel->hide_all();
                b.open(url);
                toplevel->signal_emit("destroy"); },
            (string)uri);
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
    toplevel->add(hbox);
    toplevel->signal_connect( "destroy", lambda() { exit(0); } );
    toplevel->move(conf->x,conf->y);
    toplevel->show_all();
    toplevel->raise();
    toplevel->activate_focus();
    return -1;
}
