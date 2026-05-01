/**
 * Forbid synchronous `setX(...)` calls inside `useEffect` / `useLayoutEffect` /
 * `useInsertionEffect` bodies.
 *
 * Allowed escape hatches:
 *   - inside any nested function (event handlers, setTimeout, Promise.then,
 *     IntersectionObserver / ResizeObserver / MutationObserver callbacks)
 *   - inside `useEffectEvent(...)` argument functions
 *
 * Rationale: synchronous setX inside an effect cascades re-renders and is the
 * structural source of the page-revisit / display-recovery defect that has
 * resisted multiple bug-fix attempts. The rule is the user's permanent fix.
 */

const EFFECT_HOOKS = new Set([
  "useEffect",
  "useLayoutEffect",
  "useInsertionEffect",
]);

const SETTER_PATTERN = /^set[A-Z]/;

// DOM globals shaped like setX setters but unrelated to React state.
const NON_SETTER_NAMES = new Set([
  "setTimeout",
  "setInterval",
  "setImmediate",
]);

/** @type {import("eslint").Rule.RuleModule} */
const rule = {
  meta: {
    type: "problem",
    docs: {
      description:
        "Disallow synchronous setState calls inside useEffect / useLayoutEffect / useInsertionEffect bodies.",
    },
    schema: [],
    messages: {
      forbidden:
        "`{{ name }}` cannot be called synchronously inside an effect. Move it into a store action, an event handler, or wrap the logic in `useEffectEvent`.",
    },
  },
  create(context) {
    return {
      CallExpression(node) {
        if (node.callee.type !== "Identifier") {
          return;
        }
        if (!SETTER_PATTERN.test(node.callee.name)) {
          return;
        }
        if (NON_SETTER_NAMES.has(node.callee.name)) {
          return;
        }
        if (!isInsideEffectBody(node)) {
          return;
        }
        context.report({
          node,
          messageId: "forbidden",
          data: { name: node.callee.name },
        });
      },
    };
  },
};

function isInsideEffectBody(node) {
  let current = node.parent;
  while (current) {
    if (isFunctionBoundary(current)) {
      // Hit a function boundary that is itself the effect callback?
      const effectAncestor = effectCallExpressionFor(current);
      if (effectAncestor) {
        return true;
      }
      // Hit a useEffectEvent argument? That is an explicit escape hatch.
      if (isUseEffectEventArgument(current)) {
        return false;
      }
      // Any other nested function (event handler, setTimeout callback, IO
      // callback, Promise.then, ...) — setX there is fine.
      return false;
    }
    current = current.parent;
  }
  return false;
}

function isFunctionBoundary(node) {
  return (
    node.type === "ArrowFunctionExpression" ||
    node.type === "FunctionExpression" ||
    node.type === "FunctionDeclaration"
  );
}

function effectCallExpressionFor(fnNode) {
  const parent = fnNode.parent;
  if (!parent || parent.type !== "CallExpression") {
    return null;
  }
  if (parent.arguments[0] !== fnNode) {
    return null;
  }
  const callee = parent.callee;
  if (callee.type !== "Identifier" || !EFFECT_HOOKS.has(callee.name)) {
    return null;
  }
  return parent;
}

function isUseEffectEventArgument(fnNode) {
  const parent = fnNode.parent;
  if (!parent || parent.type !== "CallExpression") {
    return false;
  }
  if (parent.arguments[0] !== fnNode) {
    return false;
  }
  const callee = parent.callee;
  return callee.type === "Identifier" && callee.name === "useEffectEvent";
}

export default {
  rules: {
    "no-set-state-in-effect": rule,
  },
};
