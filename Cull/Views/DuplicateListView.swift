import SwiftUI

struct DuplicateListView: View {
    @Bindable var viewModel: ScanViewModel

    var body: some View {
        List(viewModel.duplicateGroups, selection: Binding(
            get: { viewModel.selectedGroup?.id },
            set: { id in
                viewModel.selectedGroup = viewModel.duplicateGroups.first { $0.id == id }
            }
        )) { group in
            DuplicateGroupRow(group: group)
                .tag(group.id)
        }
        .listStyle(.sidebar)
    }
}
