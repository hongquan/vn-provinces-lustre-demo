import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h

import common.{
  type Model, UserClickedClearOnProvinceCbx, UserClickedClearOnWardCbx,
  UserFocusedProvinceCbx, UserFocusedWardCbx, UserSelectedProvince,
  UserSelectedWard, UserTextInputProvince, UserTextInputWard,
}
import component/combobox
import mytype/province.{type Province}
import mytype/ward.{type SourceWard, type Ward}

pub fn show_brief_info_province(province: Province) {
  h.dl([a.class("max-w-md mt-8")], [
    h.dt([a.class("font-semibold text-lg")], [h.text(province.name)]),
    h.dt([a.class("flex")], [
      h.span([a.class("block")], [h.text("Mã số:")]),
      h.span([a.class("block flex-grow text-end")], [
        h.text(int.to_string(province.code)),
      ]),
    ]),
  ])
}

pub fn show_brief_info_ward(ward: Ward) {
  h.dl([a.class("max-w-md mt-8")], [
    h.dt([a.class("font-semibold text-lg")], [h.text(ward.name)]),
    h.dt([a.class("flex")], [
      h.span([a.class("block")], [h.text("Mã số:")]),
      h.span([a.class("block flex-grow text-end")], [
        h.text(int.to_string(ward.code)),
      ]),
    ]),
  ])
}

pub fn view(model: Model) -> Element(common.Message) {
  let province_choices =
    model.filtered_provinces |> json.array(province.province_to_json)
  let province_preselect = case model.selected_province {
    Some(p) -> [combobox.preselect_code(p.code)]
    None -> []
  }
  let ward_choices = model.filtered_wards |> json.array(ward.ward_to_json)
  let ward_preselect = case model.selected_ward {
    Some(w) -> [combobox.preselect_code(w.code)]
    None -> []
  }
  h.div([a.class("space-y-8 sm:flex sm:flex-row sm:space-x-8 sm:space-y-0")], [
    h.div([], [
      h.label([a.class("text-lg")], [h.text("Tỉnh thành")]),
      combobox.element(
        [
          a.property("choices", province_choices),
          combobox.on_focused(UserFocusedProvinceCbx),
          combobox.on_text_input(UserTextInputProvince),
          combobox.on_selected(UserSelectedProvince),
          combobox.on_clear_clicked(UserClickedClearOnProvinceCbx),
        ]
        |> list.append(province_preselect),
      ),
      model.selected_province
        |> option.map(show_brief_info_province)
        |> option.unwrap(element.none()),
    ]),
    h.div([], [
      h.label([a.class("text-lg")], [h.text("Phường xã")]),
      combobox.element(
        [
          a.property("choices", ward_choices),
          combobox.on_focused(UserFocusedWardCbx),
          combobox.on_text_input(UserTextInputWard),
          combobox.on_selected(UserSelectedWard),
          combobox.on_clear_clicked(UserClickedClearOnWardCbx),
        ]
        |> list.append(ward_preselect),
      ),
      model.selected_ward
        |> option.map(show_brief_info_ward)
        |> option.unwrap(element.none()),
      // Show source wards table if we have source_wards
      case model.source_wards {
        [] -> element.none()
        wards -> {
          h.div([a.class("mt-8")], [
            h.h3([a.class("text-lg font-semibold mb-4")], [
              h.text("Phường/Xã nguồn (trước sáp nhập 2025)"),
            ]),
            h.table(
              [
                a.class(
                  "min-w-full border-collapse border border-gray-400 dark:border-gray-600",
                ),
              ],
              [
                render_source_wards_table_header(),
                h.tbody(
                  [a.class("bg-white dark:bg-gray-800")],
                  wards |> list.map(render_source_ward),
                ),
              ],
            ),
          ])
        }
      },
    ]),
  ])
}

fn render_source_ward(ward: SourceWard) {
  h.tr([a.class("even:bg-gray-50 dark:even:bg-gray-700")], [
    h.td([a.class("border border-gray-300 dark:border-gray-600 px-4 py-2")], [
      h.text(int.to_string(ward.code)),
    ]),
    h.td([a.class("border border-gray-300 dark:border-gray-600 px-4 py-2")], [
      h.text(ward.name),
    ]),
    h.td([a.class("border border-gray-300 dark:border-gray-600 px-4 py-2")], [
      h.text(int.to_string(ward.district_code)),
    ]),
    h.td([a.class("border border-gray-300 dark:border-gray-600 px-4 py-2")], [
      h.text(int.to_string(ward.province_code)),
    ]),
  ])
}

pub fn render_source_wards_table_header() {
  let css_class =
    "border border-gray-300 dark:border-gray-600 px-4 py-2 text-left"
  h.thead([a.class("bg-gray-100 dark:bg-gray-900")], [
    h.tr([], [
      h.th([a.class(css_class)], [h.text("Mã số")]),
      h.th([a.class(css_class)], [h.text("Tên")]),
      h.th([a.class(css_class)], [h.text("Mã huyện")]),
      h.th([a.class(css_class)], [h.text("Mã tỉnh")]),
    ]),
  ])
}
