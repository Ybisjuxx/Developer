import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
import Home from './pages/Home';
import Courses from './pages/Courses';
import Programs from './pages/Programs';
import Auth from './pages/Auth';
import DynamicBackground from './components/DynamicBackground';

function App() {
  return (
    <Router>
      <div className="flex-column min-h-screen">
        <DynamicBackground />
        <Navbar />
        <main className="flex-grow">
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/cursos" element={<Courses />} />
            <Route path="/programas" element={<Programs />} />
            <Route path="/login" element={<Auth />} />
          </Routes>
        </main>
        <Footer />
      </div>
    </Router>
  );
}

export default App;
