import React from 'react';

function Greeting({ name, count }) {
  const emoji = count > 10 ? '🎉' : '👋';

  return (
    <div className="greeting-card">
      <h2>{emoji} Hello, {name}!</h2>
      <p>You have visited {count} times.</p>
      {count > 5 && (
        <span className="badge">Frequent visitor</span>
      )}
    </div>
  );
}

function App() {
  const [visits, setVisits] = React.useState(0);

  React.useEffect(() => {
    setVisits(v => v + 1);
  }, []);

  return (
    <main>
      <Greeting name="Developer" count={visits} />
      <button onClick={() => setVisits(v => v + 1)}>
        Simulate Visit
      </button>
    </main>
  );
}

export default App;
