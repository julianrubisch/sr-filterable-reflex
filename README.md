Decouple your filtering and faceted search using concerns

**How**
- Use a `Filterable` concern to [mediate](https://en.wikipedia.org/wiki/Mediator_pattern) between your controllers/concerns and the filtering logic
- In separate `Filter` classes, define how and which rules apply, and how to update filter params

**Caveats**

The `Book` and `Restaurant` classes in this example mimick an `ActiveRecord` model. The array refinements simply serve as stand-ins for model scopes or AR queries.