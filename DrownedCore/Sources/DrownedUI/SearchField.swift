import SwiftUI

struct SearchField: View {
    @Bindable var searchModel: SearchModel

    var body: some View {
        return MacSearchField(
            text: $searchModel.query,
            placeholder: "Search location",
            onTextChange: searchModel.updateQuery
        )
        .frame(width: 360, height: 28, alignment: .center)
    }
}
