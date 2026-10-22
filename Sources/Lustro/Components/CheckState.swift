enum CheckState {
    case on
    case off
    case mixed

    init(selected: Int, of total: Int) {
        self = selected == 0 ? .off : (selected == total ? .on : .mixed)
    }
}
