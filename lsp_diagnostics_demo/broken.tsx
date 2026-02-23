import React from 'react';

interface Props {
  name: string;
}

function Greet(props: Props): JSX.Element {
  const count: number = "hello";  // type mismatch
  return (
    <div>
      <h1>{props.nonExistent}</h1>
      <p>Unclosed tag
    </div>
  );
}
