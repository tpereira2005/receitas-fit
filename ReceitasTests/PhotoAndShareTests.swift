import Foundation
import SwiftUI
import Testing
@testable import Receitas

@MainActor
struct PhotoAndShareTests {
    /// Fotografia vertical num cartão largo: o foco em baixo mostra a parte de baixo, sem bordas vazias.
    @Test func focusKeepsPointVisibleWithoutGaps() {
        let image = CGSize(width: 1000, height: 2000)
        let card = CGSize(width: 300, height: 200)
        let centered = FocusedImage.frame(for: image, in: card, focus: .center)
        #expect(centered.width == 300 && centered.height == 600)
        #expect(centered.minY == -200)

        let bottom = FocusedImage.frame(for: image, in: card, focus: UnitPoint(x: 0.5, y: 0.9))
        // O ponto (y = 0,9 → 540 pt) fica a meio do cartão, mas nunca além do limite da imagem.
        #expect(bottom.minY == -400)
        #expect(bottom.maxY == 200)

        let top = FocusedImage.frame(for: image, in: card, focus: UnitPoint(x: 0.5, y: 0))
        #expect(top.minY == 0)
    }

    @Test func duplicateIsANewRecipeWithSameContent() {
        let recipe = Recipe(title: "Panquecas")
        recipe.servings = 3
        recipe.isFavorite = true
        recipe.cookedDates = [.now]
        recipe.photoFocusY = 0.2
        recipe.steps = [RecipeStep(text: "Misturar")]

        let draft = RecipeDraft(duplicating: recipe)
        #expect(draft.title == "Panquecas (cópia)")
        #expect(draft.servings == 3)
        #expect(draft.photoFocusY == 0.2)

        let copy = Recipe()
        draft.apply(to: copy, foods: [:])
        #expect(copy.id != recipe.id)
        #expect(copy.steps.map(\.text) == ["Misturar"])
        // Favorita e histórico não passam para a cópia.
        #expect(!copy.isFavorite)
        #expect(copy.cookedDates.isEmpty)
    }

    @Test func shareImagesHaveExpectedSizes() throws {
        let recipe = Recipe(title: "Bowl de frango")
        recipe.perServing = NutritionFacts(calories: 473, protein: 43.4, carbs: 50, fat: 9)
        let content = RecipeShareCard.Content(recipe: recipe)
        let square = try #require(RecipeShareCard.render(content, format: .square))
        let story = try #require(RecipeShareCard.render(content, format: .story))
        #expect(square.size.width * square.scale == 1080)
        #expect(square.size.height * square.scale == 1080)
        #expect(story.size.height * story.scale == 1920)
    }
}
