# Updating an existing project to a newer template version

The template will keep improving after any given project is created
from it - bug fixes, styling corrections, new sub-systems. This
document is about deciding what (if anything) to pull into a project
that's already been built and customised, and how that actually
happens in practice.

## There is no automatic merge

A real project diverges from the template the moment it gets its own
business logic, branding, and customer-specific fields. There's no
tool that can mechanically "merge in the latest template" the way a
package manager updates a dependency - the moment a project has
edited, say, the Customers page to add real fields, a mechanical
merge of the template's own Customers page would either silently
overwrite that work or fail outright.

So updating a project is always a judgement call, made by you and
Claude together, informed by:

- **`TEMPLATE-VERSION.txt`** (in the template repo) - the template's
  current version.
- **`project.conf`'s `TEMPLATE_VERSION_AT_CREATION`** (in the
  project's own repo) - which version that specific project started
  from. This value is set once, at creation, and never changes
  automatically - it's a historical record, not a live pointer.
- **`docs/TEMPLATE-CHANGELOG.md`** (in the template repo) - what
  actually changed, in order, between any two versions.

## How to actually do it

1. **Check the gap.** Compare the project's `TEMPLATE_VERSION_AT_CREATION`
   against the template's current `TEMPLATE-VERSION.txt`. Read every
   changelog entry in between.
2. **Decide what's relevant.** Not everything in the changelog will
   apply - a bug fix to the Issues tabbed modal is irrelevant to a
   project that didn't include the Issues sub-system at all. Pick
   the entries that are genuinely relevant to this project.
3. **Ask Claude to apply the relevant changes to this specific
   project**, describing what you want pulled in (referencing the
   changelog entry is enough - "bring in the Customers table styling
   fix from the 1.1.0 changelog entry"). Claude reads both the
   template's current version of the relevant file(s) and this
   project's current version, and applies the change with the same
   care as porting a fix between pages within the template itself -
   adapting it to whatever this project has already customised,
   rather than overwriting it wholesale.
4. **Claude does NOT update `TEMPLATE_VERSION_AT_CREATION`
   automatically** after doing this - that field stays as a record of
   when the project was *created*, not a running tally of every patch
   since pulled in. If you want a record of what's since been pulled
   in, ask Claude to add a note to that project's own `CHANGES.txt`/
   commit history, the same way any other change gets recorded.

## When NOT to bother

Plenty of template improvements simply don't matter for an existing,
working project - a CSS tweak nobody's noticed, a sub-system the
project never used, a doc-only change. There's no obligation to chase
every template version. Treat the changelog as a menu, not a todo
list.

## When you definitely SHOULD pull something in

A security-relevant fix (an RLS policy gap, a privilege-escalation
hole, anything in that category) is the one case worth treating as
non-optional regardless of how unrelated the rest of that version's
changes are. If a changelog entry is flagged as a security fix,
bring it into every live project that has the affected table/feature,
not just the ones you happen to be actively working on.
