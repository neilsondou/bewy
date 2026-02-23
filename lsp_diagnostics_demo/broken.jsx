import React from 'react';

function App() {
  const name = ;  // missing expression
  return (
    <div>
      <h1>Hello {undefinedVar}</h1>
      <p>Unclosed paragraph
      <span>{if (true) "bad"}</span>  // invalid JSX expression
    </div>
  );
}
