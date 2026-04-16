module AdminHelper
  # Renders a sortable column header link.
  # Toggles asc/desc when the column is already active.
  def sort_link(column, label)
    current_col = params[:sort]
    current_dir = params[:dir]

    if current_col == column
      next_dir = current_dir == "asc" ? "desc" : "asc"
      arrow = current_dir == "asc" ? " ▲" : " ▼"
    else
      next_dir = "desc"
      arrow = ""
    end

    link_to(
      "#{label}#{arrow}".html_safe,
      admin_material_prices_path(
        sort: column,
        dir: next_dir,
        trade: params[:trade],
        page: 1
      )
    )
  end
end
