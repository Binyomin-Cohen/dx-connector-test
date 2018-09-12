public virtual class ColumnConfig {
    public List<Column> unusedColumns { get; set; }
    public List<Column> activeColumns { get; set; }

    public ColumnConfig() {
        this.unusedColumns = new List<Column>();
        this.activeColumns = new List<Column>();
    }

    public void addStaticColumns(List<Column> columns, List<Column> staticColumns) {

        for (Column col : staticColumns) {
            col.isStatic = col.isDefault = true;
        }

        if (columns.isEmpty()) {
            columns.addAll(staticColumns);
        } else {
            for(Integer i = 0; i < staticColumns.size(); i++) {
                columns.add(i, staticColumns[i]);
            }
        }
    }
}