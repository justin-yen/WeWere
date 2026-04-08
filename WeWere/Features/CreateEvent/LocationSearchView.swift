import SwiftUI
import Combine

// MARK: - Place Autocomplete Models

struct PlacePrediction: Decodable, Identifiable {
    let placeId: String
    let description: String
    let structuredFormatting: StructuredFormatting

    var id: String { placeId }

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case description
        case structuredFormatting = "structured_formatting"
    }

    struct StructuredFormatting: Decodable {
        let mainText: String
        let secondaryText: String

        enum CodingKeys: String, CodingKey {
            case mainText = "main_text"
            case secondaryText = "secondary_text"
        }
    }
}

struct PlaceDetails: Decodable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
}

// MARK: - Location Search View

struct LocationSearchView: View {
    @Binding var locationText: String
    var onLocationSelected: (String, String, Double, Double) -> Void
    var onCleared: () -> Void

    @State private var searchText = ""
    @State private var predictions: [PlacePrediction] = []
    @State private var isSearching = false
    @State private var showDropdown = false
    @State private var selectedName: String?
    @State private var debounceTask: Task<Void, Never>?

    private let api = APIClient.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let name = selectedName {
                // Selected location chip
                selectedLocationChip(name: name)
            } else {
                // Search field
                searchField

                // Dropdown
                if showDropdown && !predictions.isEmpty {
                    dropdownList
                }
            }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        TextField("", text: $searchText, prompt:
            Text("Search for a location")
                .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                .foregroundStyle(WeWereColors.outlineVariant)
        )
        .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Color(hex: "191919"))
        .cornerRadius(8)
        .onChange(of: searchText) { _, newValue in
            debounceTask?.cancel()
            if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                predictions = []
                showDropdown = false
                return
            }
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                guard !Task.isCancelled else { return }
                await fetchPredictions(query: newValue)
            }
        }
    }

    // MARK: - Dropdown List

    private var dropdownList: some View {
        VStack(spacing: 0) {
            ForEach(predictions) { prediction in
                Button {
                    Task {
                        await selectPrediction(prediction)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prediction.structuredFormatting.mainText)
                            .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                            .foregroundStyle(WeWereColors.onSurface)
                            .lineLimit(1)

                        Text(prediction.structuredFormatting.secondaryText)
                            .font(.custom(WeWereFontFamily.jakartaRegular, size: 12))
                            .foregroundStyle(WeWereColors.outline)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                if prediction.id != predictions.last?.id {
                    Divider()
                        .overlay(WeWereColors.outlineVariant.opacity(0.3))
                }
            }
        }
        .background(Color(hex: "282828"))
        .cornerRadius(8)
        .padding(.top, 4)
    }

    // MARK: - Selected Location Chip

    private func selectedLocationChip(name: String) -> some View {
        HStack(spacing: WeWereSpacing.xs) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(WeWereColors.onSurface)

            Text(name)
                .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                .foregroundStyle(WeWereColors.onSurface)
                .lineLimit(1)

            Spacer()

            Button {
                selectedName = nil
                searchText = ""
                predictions = []
                showDropdown = false
                locationText = ""
                onCleared()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(WeWereColors.outline)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Color(hex: "191919"))
        .cornerRadius(8)
    }

    // MARK: - API Calls

    @MainActor
    private func fetchPredictions(query: String) async {
        do {
            let results: [PlacePrediction] = try await api.get(
                "/places/autocomplete?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
            )
            predictions = results
            showDropdown = true
        } catch {
            print("Location autocomplete error: \(error)")
            predictions = []
            showDropdown = false
        }
    }

    @MainActor
    private func selectPrediction(_ prediction: PlacePrediction) async {
        do {
            let details: PlaceDetails = try await api.get(
                "/places/details/\(prediction.placeId)"
            )
            selectedName = details.name
            searchText = details.name
            locationText = details.name
            predictions = []
            showDropdown = false
            onLocationSelected(details.name, details.address, details.latitude, details.longitude)
        } catch {
            print("Place details error: \(error)")
            // Fall back to using the prediction description
            selectedName = prediction.structuredFormatting.mainText
            searchText = prediction.structuredFormatting.mainText
            locationText = prediction.structuredFormatting.mainText
            predictions = []
            showDropdown = false
        }
    }
}
