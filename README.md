# The Drowning

The Drowning is a macOS app for following and exploring the IOM Missing
Migrants Project dataset. It presents newly recorded migrant deaths and
disappearances on a map, with filters that help you understand where incidents
were recorded, which routes were involved, what causes were reported, and how
the records changed over time.

## Data Source

The app uses the [IOM Missing Migrants Project dataset on Humanitarian Data
Exchange](https://data.humdata.org/dataset/missing-migrants-project).

Data: IOM's Missing Migrants Project (missingmigrants.iom.int), licensed under
CC BY 4.0. Data has been reformatted and filtered for display; figures are
minimum estimates and locations are approximate.

## What You Can Do

- Browse recorded incidents on an interactive macOS map.
- Filter incidents by region, migration route, cause, and date.
- Search for places and move the map without changing your incident filters.
- Open incident details to see the available record fields and source links.
- Switch between standard and hybrid map styles.
- Refresh the local dataset and receive grouped notifications for newly
  recorded incidents in regions you care about.

The app is not a live emergency feed. It works with curated batch data, so new
records should be read as newly recorded by the source dataset, not necessarily
as events that just happened.

## Running Locally

Install the development tools, generate the Xcode project, then open the project
in Xcode or Cursor:

```sh
brew install xcodegen xcode-build-server xcbeautify swiftformat
xcodegen generate
```

The generated project is `TheDrowning.xcodeproj`. Build and run the
`TheDrowning` scheme to launch the app.
