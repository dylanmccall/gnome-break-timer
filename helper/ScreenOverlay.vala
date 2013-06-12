/*
 * This file is part of Brain Break.
 * 
 * Brain Break is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * Brain Break is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with Brain Break.  If not, see <http://www.gnu.org/licenses/>.
 */

/* FIXME: Do another overlay widget and kill the set_format junk :) */

public class ScreenOverlay : Gtk.Window {
	public enum Format {
		SILENT,
		MINI,
		FULL
	}
	protected Format format;
	private uint fade_timeout;
	
	public ScreenOverlay() {
		Object(type: Gtk.WindowType.POPUP);
		
		/*
		this.set_decorated(false);
		this.stick();
		this.set_keep_above(true);
		this.set_skip_pager_hint(true);
		this.set_skip_taskbar_hint(true);
		this.set_accept_focus(false);
		*/
		
		this.format = Format.FULL;
		
		Gdk.Screen screen = this.get_screen();
		screen.composited_changed.connect(this.on_screen_composited_changed);
		this.on_screen_composited_changed(screen);
		
		Gtk.StyleContext style = this.get_style_context();
		style.add_class("brainbreak-screen-overlay");

		this.realize.connect(this.on_realize);

		this.realize();
	}

	protected void apply_format(Format format) {
		switch(format) {
		case Format.SILENT:
			this.fade_out();
			break;

		case Format.MINI:
			this.input_shape_combine_region((Cairo.Region)null);
			
			this.set_size_request(-1, -1);
			this.resize(1, 1);

			this.fade_in();

			break;

		case Format.FULL:
			/* empty input region to ignore any input */
			this.input_shape_combine_region(new Cairo.Region());
			
			Gdk.Screen screen = this.get_screen();
			int monitor = screen.get_monitor_at_window(this.get_window());
			Gdk.Rectangle geom;
			screen.get_monitor_geometry(monitor, out geom);
			
			string? session = Environment.get_variable("DESKTOP_SESSION");
			
			if (session == "gnome-shell") {
				/* make sure the overlay doesn't cause the top panel to hide */
				// FIXME: position _properly_ around panel, using _NET_WORKAREA or a maximized toplevel window
				this.set_size_request(geom.width, geom.height-1);
				this.move(0, 1);
			} else {
				this.set_size_request(geom.width, geom.height);
			}

			this.fade_in();
			
			break;
		}
	}
	
	public void set_format(Format format) {
		this.format = format;
		if (this.get_realized()) this.apply_format(format);
	}

	public virtual void fade_in(double rate = 0.01) {
		assert(rate > 0);

		if (this.format == Format.SILENT) return;

		double opacity;
		if (this.get_visible()) {
			opacity = this.get_opacity();
		} else {
			opacity = 0.0;
			this.set_opacity(opacity);
		}

		this.show();

		if (this.fade_timeout > 0) Source.remove(this.fade_timeout);
		this.fade_timeout = Timeout.add(20, () => {
			opacity += rate;
			this.set_opacity(opacity);
			bool do_continue = opacity < 1.0;
			return do_continue;
		});
	}

	public virtual void fade_out(double rate = 0.02) {
		assert(rate > 0);

		double opacity;
		if (this.get_visible()) {
			opacity = this.get_opacity();
		} else {
			return;
		}

		if (this.fade_timeout > 0) Source.remove(this.fade_timeout);
		this.fade_timeout = Timeout.add(20, () => {
			opacity -= rate;
			this.set_opacity(opacity);
			bool do_continue = opacity > 0.0;
			if (do_continue == false) this.hide();
			return do_continue;
		});
	}

	public virtual void pop_out() {
		// TODO: Pretty animation when break is finished.
		// For now we'll just fade out.
		this.fade_out();
	}
	
	private void on_screen_composited_changed(Gdk.Screen screen) {
		Gdk.Visual? screen_visual = null;
		if (screen.is_composited()) {
			screen_visual = screen.get_rgba_visual();
		}
		if (screen_visual == null) {
			screen_visual = screen.get_system_visual();
		}
		this.set_visual(screen_visual);
	}
	
	private void on_realize() {
		this.apply_format(this.format);
	}
}

