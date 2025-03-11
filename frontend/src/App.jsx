import { Routes, Route } from 'react-router-dom'
import Header from './components/Header/Header.jsx'
import Footer from './components/Footer/Footer.jsx'
import Home from './pages/Home/Home.jsx'
import Issue from './pages/Issue/Issue.jsx'
import Verify from './pages/Verify/Verify.jsx'
import About from './pages/About/About.jsx'
import './App.css'

function App() {
  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-grow">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/issue" element={<Issue />} />
          <Route path="/verify" element={<Verify />} />
          <Route path="/about" element={<About />} />
        </Routes>
      </main>
      <Footer />
    </div>
  )
}

export default App