import XCTest

/// Testes de interface: abrem a app no simulador e tocam nos ecrãs como um utilizador.
/// Servem para apanhar erros que os testes do código não veem (uma janela que fecha sozinha,
/// um botão que deixa de responder…). A app usa o conteúdo de origem (gelados e Cookie Dough Cake).
@MainActor
final class ReceitasFitUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        // "screenshots": sem cópias automáticas durante os testes.
        app.launchArguments = ["-AppleLanguages", "(pt-PT)", "-AppleLocale", "pt_PT", "-screenshots", "YES"] + arguments
        app.launch()
        return app
    }

    private func element(_ query: XCUIElementQuery, startingWith text: String) -> XCUIElement {
        query.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    /// Faz scroll até o elemento aparecer (as páginas das receitas são compridas).
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 8) {
        var remaining = attempts
        while !element.isHittable && remaining > 0 {
            app.swipeUp()
            remaining -= 1
        }
    }

    /// O erro da versão 1.3: "Ajustar enquadramento" fechava o editor inteiro.
    func testPhotoFocusEditorKeepsTheRecipeEditorOpen() {
        let app = launch(["-screenshotEditFirst", "YES"])
        XCTAssertTrue(app.navigationBars["Editar receita"].waitForExistence(timeout: timeout))

        app.buttons["Ajustar enquadramento"].tap()
        XCTAssertTrue(app.navigationBars["Enquadramento"].waitForExistence(timeout: timeout))

        // Arrastar a fotografia e aproximar com o controlo.
        let photo = app.otherElements["Fotografia da receita"]
        XCTAssertTrue(photo.waitForExistence(timeout: timeout))
        let start = photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: photo.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4)))
        app.sliders.firstMatch.adjust(toNormalizedSliderPosition: 0.5)

        app.navigationBars["Enquadramento"].buttons["OK"].tap()
        XCTAssertTrue(app.navigationBars["Editar receita"].waitForExistence(timeout: timeout))
        XCTAssertFalse(app.navigationBars["Enquadramento"].exists)
    }

    func testFilterPanelAppliesAndShowsTheFilter() {
        let app = launch(["-tab", "recipes"])
        let filters = app.buttons["Filtros"]
        XCTAssertTrue(filters.waitForExistence(timeout: timeout))
        filters.tap()

        let lowCalorie = element(app.switches, startingWith: "Até 400 kcal")
        XCTAssertTrue(lowCalorie.waitForExistence(timeout: timeout))
        lowCalorie.switches.firstMatch.tap()
        element(app.buttons, startingWith: "Mostrar").tap()

        XCTAssertTrue(app.buttons["Remover filtro Até 400 kcal"].waitForExistence(timeout: timeout))
    }

    func testSettingsPagesOpenAndGoBack() {
        let app = launch()
        let settings = app.buttons["Definições"]
        XCTAssertTrue(settings.waitForExistence(timeout: timeout))
        settings.tap()

        for page in ["Cópias de segurança", "Apagadas recentemente", "Etiquetas", "SideStore"] {
            let row = element(app.buttons, startingWith: page)
            XCTAssertTrue(row.waitForExistence(timeout: timeout), "Falta a linha \(page)")
            row.tap()
            XCTAssertTrue(app.navigationBars[page].waitForExistence(timeout: timeout), "Não abriu \(page)")
            app.navigationBars[page].buttons.firstMatch.tap()
            XCTAssertTrue(app.navigationBars["Definições"].waitForExistence(timeout: timeout))
        }
    }

    func testCookingModeMovesBetweenSteps() {
        let app = launch(["-screenshotOpenFirst", "YES"])
        let cook = element(app.buttons, startingWith: "Modo cozinhar")
        XCTAssertTrue(cook.waitForExistence(timeout: timeout))
        scrollTo(cook, in: app)
        cook.tap()

        XCTAssertTrue(element(app.staticTexts, startingWith: "Passo 1 de").waitForExistence(timeout: timeout))
        app.buttons["Seguinte"].tap()
        XCTAssertTrue(element(app.staticTexts, startingWith: "Passo 2 de").waitForExistence(timeout: timeout))
        app.buttons["Fechar"].tap()
        XCTAssertTrue(cook.waitForExistence(timeout: timeout))
    }

    /// Apagar uma receita manda-a para "Apagadas recentemente", de onde se recupera.
    func testDeletedRecipeCanBeRestored() {
        let app = launch(["-screenshotOpenFirst", "YES"])
        let more = app.buttons["Mais"]
        XCTAssertTrue(more.waitForExistence(timeout: timeout))
        more.tap()
        app.buttons["Apagar"].tap()
        app.alerts.buttons["Apagar"].tap()

        let settings = app.buttons["Definições"]
        XCTAssertTrue(settings.waitForExistence(timeout: timeout))
        settings.tap()
        element(app.buttons, startingWith: "Apagadas recentemente").tap()

        let deleted = app.cells.firstMatch
        XCTAssertTrue(deleted.waitForExistence(timeout: timeout))
        deleted.swipeRight()
        app.buttons["Recuperar"].tap()
        XCTAssertTrue(app.staticTexts["Nada apagado"].waitForExistence(timeout: timeout))
    }
}
