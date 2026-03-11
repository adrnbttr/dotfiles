# Documentation Generator Prompt

Please generate comprehensive documentation for this code.

## Documentation Requirements

### 1. **API Documentation** (if applicable)
- Endpoint descriptions
- Request/response formats
- Authentication requirements
- Error codes
- Rate limiting

### 2. **Function/Method Documentation**
- Purpose and functionality
- Parameters with types and descriptions
- Return values
- Side effects
- Exceptions thrown

### 3. **Class Documentation** (if applicable)
- Purpose and responsibility
- Public interface
- Internal implementation notes
- Usage examples
- Dependencies

### 4. **Configuration Documentation**
- Environment variables
- Configuration files
- Default values
- Required vs optional settings

### 5. **Setup & Deployment**
- Installation instructions
- Build steps
- Deployment procedures
- Dependencies installation

### 6. **Usage Examples**
- Common use cases
- Code examples
- Integration examples
- Troubleshooting guide

## Response Format

Please provide documentation in this structure:

### Overview
- Brief description of what the code does
- Key features and capabilities

### Quick Start
```bash
# Installation commands
# Basic usage example
```

### API Reference (if applicable)
| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/...` | GET | Description | Yes/No |

### Functions/Methods
```language
def function_name(param1: type, param2: type) -> return_type:
    """
    Brief description.
    
    Args:
        param1: Description of param1
        param2: Description of param2
    
    Returns:
        Description of return value
    
    Raises:
        ExceptionType: When this happens
    
    Example:
        >>> function_name(value1, value2)
        expected_output
    """
```

### Configuration
```env
# .env.example
API_KEY=your_api_key_here
DATABASE_URL=postgresql://...
LOG_LEVEL=INFO
```

### Examples
```language
# Basic usage
# Advanced usage
# Error handling example
```

### Troubleshooting
| Problem | Solution |
|---------|----------|
| Error X | Fix Y |
| Performance issue | Optimization Z |

### Dependencies
- List of required dependencies
- Version constraints
- Development dependencies

### Architecture Notes
- High-level architecture diagram (in text)
- Key design decisions
- Scalability considerations

### Security Considerations
- Authentication/authorization
- Data protection
- Input validation
- Audit logging